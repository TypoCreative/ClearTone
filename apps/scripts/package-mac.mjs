import { mkdtemp, readdir, rm } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { dirname, join, resolve } from 'node:path'
import { spawn, spawnSync } from 'node:child_process'
import { randomBytes } from 'node:crypto'
import { tmpdir } from 'node:os'

const scriptDirectory = dirname(fileURLToPath(import.meta.url))
const appDirectory = resolve(scriptDirectory, '..')
const projectRoot = resolve(appDirectory, '..')
const rootCertificateName = '_dev-id-apple.p12'

async function findRootCertificate() {
  const entries = await readdir(projectRoot, { withFileTypes: true })
  const certificate = entries.find(
    (entry) => entry.isFile() && entry.name === rootCertificateName,
  )

  if (!certificate) return undefined

  return join(projectRoot, certificate.name)
}

function certificateAcceptsPassword(certificate, password) {
  const result = spawnSync(
    '/usr/bin/openssl',
    ['pkcs12', '-in', certificate, '-passin', 'env:CLEARTONE_CERTIFICATE_PASSWORD', '-noout'],
    {
      env: { ...process.env, CLEARTONE_CERTIFICATE_PASSWORD: password },
      stdio: 'ignore',
    },
  )

  return result.status === 0
}

function runSecurity(args, errorMessage, { captureOutput = false, allowFailure = false } = {}) {
  const result = spawnSync('/usr/bin/security', args, {
    encoding: captureOutput ? 'utf8' : undefined,
    stdio: captureOutput ? ['ignore', 'pipe', 'pipe'] : 'ignore',
  })

  if (result.status !== 0 && !allowFailure) {
    throw new Error(errorMessage)
  }

  return captureOutput ? result.stdout ?? '' : ''
}

function getUserKeychains() {
  const output = runSecurity(
    ['list-keychains', '-d', 'user'],
    'Could not read the macOS user keychain list.',
    { captureOutput: true },
  )

  return output
    .split('\n')
    .map((line) => line.trim().replace(/^"|"$/g, ''))
    .filter(Boolean)
}

function getIdentityNames(output) {
  return output
    .split('\n')
    .map((line) => line.match(/"([^"]+)"/)?.[1])
    .filter(Boolean)
}

function selectSigningIdentity(identityNames) {
  const priorities = [
    'Developer ID Application:',
    'Apple Development:',
    'Mac Developer:',
    'Apple Distribution:',
  ]

  for (const prefix of priorities) {
    const identity = identityNames.find((name) => name.startsWith(prefix))
    if (identity) return identity
  }

  return identityNames[0]
}

async function createSigningKeychain(
  certificate,
  certificatePassword,
  { requireDeveloperId = false } = {},
) {
  const directory = await mkdtemp(join(tmpdir(), 'cleartone-signing-'))
  const keychain = join(directory, 'ClearTone-signing.keychain-db')
  const keychainPassword = randomBytes(32).toString('base64url')
  const originalKeychains = getUserKeychains()
  let searchListChanged = false

  const cleanup = async () => {
    if (searchListChanged && originalKeychains.length > 0) {
      runSecurity(
        ['list-keychains', '-d', 'user', '-s', ...originalKeychains],
        'Could not restore the macOS user keychain list.',
        { allowFailure: true },
      )
    }

    runSecurity(['delete-keychain', keychain], 'Could not delete the temporary signing keychain.', {
      allowFailure: true,
    })
    await rm(directory, { recursive: true, force: true })
  }

  try {
    runSecurity(
      ['create-keychain', '-p', keychainPassword, keychain],
      'Could not create the temporary ClearTone signing keychain.',
    )
    runSecurity(
      ['unlock-keychain', '-p', keychainPassword, keychain],
      'Could not unlock the temporary ClearTone signing keychain.',
    )
    runSecurity(
      ['set-keychain-settings', '-lut', '21600', keychain],
      'Could not configure the temporary ClearTone signing keychain.',
    )
    runSecurity(
      [
        'import',
        certificate,
        '-k',
        keychain,
        '-P',
        certificatePassword ?? '',
        '-T',
        '/usr/bin/codesign',
        '-T',
        '/usr/bin/productbuild',
      ],
      'The .p12 could not be imported. Re-export it with its private key and try again.',
    )
    runSecurity(
      [
        'set-key-partition-list',
        '-S',
        'apple-tool:,apple:',
        '-s',
        '-k',
        keychainPassword,
        keychain,
      ],
      'Could not grant codesign access to the temporary ClearTone signing keychain.',
    )

    runSecurity(
      ['list-keychains', '-d', 'user', '-s', keychain, ...originalKeychains],
      'Could not add the temporary ClearTone signing keychain to the search list.',
    )
    searchListChanged = true

    const identities = runSecurity(
      ['find-identity', '-v', '-p', 'codesigning', keychain],
      'Could not inspect the imported signing identity.',
      { captureOutput: true },
    )
    const identityNames = getIdentityNames(identities)
    const identityName = selectSigningIdentity(identityNames)

    if (!identityName) {
      const importedIdentities = getIdentityNames(
        runSecurity(
          ['find-identity', '-p', 'codesigning', keychain],
          'Could not inspect the imported signing identity.',
          { captureOutput: true },
        ),
      )
      const foundIdentity = importedIdentities[0]
      throw new Error(
        foundIdentity
          ? `The imported signing identity is not valid or trusted: ${foundIdentity}`
          : 'The .p12 does not contain a valid code-signing identity with its private key.',
      )
    }

    const isDeveloperId = identityName.startsWith('Developer ID Application:')
    if (requireDeveloperId && !isDeveloperId) {
      throw new Error(
        `A published build requires Developer ID Application, but the .p12 contains: ${identityName}`,
      )
    }

    if (!isDeveloperId) {
      console.warn(
        `Using ${identityName} for a local development build. This DMG cannot be notarized for public distribution.`,
      )
    }

    const identityQualifier = identityName.includes(':')
      ? identityName.slice(identityName.indexOf(':') + 1).trim()
      : identityName
    const usesDevelopmentSigning =
      identityName.startsWith('Apple Development:') || identityName.startsWith('Mac Developer:')

    return { keychain, identityQualifier, usesDevelopmentSigning, cleanup }
  } catch (error) {
    await cleanup()
    throw error
  }
}

async function promptForPassword() {
  if (!process.stdin.isTTY || !process.stdout.isTTY || !process.stdin.setRawMode) {
    throw new Error(
      'The root .p12 certificate is password-protected. Set CSC_KEY_PASSWORD before running npm run dist:mac.',
    )
  }

  process.stdout.write('Certificate password (input hidden): ')

  return new Promise((resolvePassword, rejectPassword) => {
    const wasRaw = process.stdin.isRaw
    let password = ''

    const finish = (error) => {
      process.stdin.off('data', onData)
      process.stdin.setRawMode(Boolean(wasRaw))
      process.stdin.pause()
      process.stdout.write('\n')

      if (error) rejectPassword(error)
      else resolvePassword(password)
    }

    const onData = (data) => {
      for (const character of data.toString()) {
        if (character === '\u0003') {
          finish(new Error('macOS packaging cancelled.'))
          return
        }

        if (character === '\r' || character === '\n') {
          finish()
          return
        }

        if (character === '\u007f' || character === '\b') {
          password = password.slice(0, -1)
          continue
        }

        if (character >= ' ') password += character
      }
    }

    process.stdin.setRawMode(true)
    process.stdin.resume()
    process.stdin.on('data', onData)
  })
}

async function getCertificatePassword(rootCertificate) {
  if (!rootCertificate) {
    return process.env.CSC_KEY_PASSWORD
  }

  if (process.env.CSC_KEY_PASSWORD !== undefined) {
    if (certificateAcceptsPassword(rootCertificate, process.env.CSC_KEY_PASSWORD)) {
      return process.env.CSC_KEY_PASSWORD
    }

    throw new Error('CSC_KEY_PASSWORD does not unlock the root .p12 certificate.')
  }

  if (certificateAcceptsPassword(rootCertificate, '')) return undefined

  const password = await promptForPassword()
  if (!certificateAcceptsPassword(rootCertificate, password)) {
    throw new Error('The certificate password is incorrect. Set CSC_KEY_PASSWORD and try again.')
  }

  return password
}

async function main() {
  const rootCertificate = process.env.CSC_LINK ? undefined : await findRootCertificate()
  const certificate = process.env.CSC_LINK ?? rootCertificate
  const certificatePassword = await getCertificatePassword(rootCertificate)
  const requestedArchitecture = process.env.CLEARTONE_TARGET_ARCH
  const cliArchitecture = process.argv.includes('--x64')
    ? 'x64'
    : process.argv.includes('--arm64')
      ? 'arm64'
      : undefined
  const targetArchitecture = requestedArchitecture ?? cliArchitecture

  if (targetArchitecture && !['x64', 'arm64'].includes(targetArchitecture)) {
    throw new Error(
      `Unsupported CLEARTONE_TARGET_ARCH: ${targetArchitecture}. Expected x64 or arm64.`,
    )
  }

  if (process.env.CSC_LINK) {
    console.log('Using macOS signing certificate from CSC_LINK.')
  } else if (rootCertificate) {
    console.log(`Using macOS signing certificate: ${rootCertificate}`)
  } else {
    console.warn(
      'No signing certificate selected; creating an unsigned build. Set CSC_LINK and CSC_KEY_PASSWORD for signed releases.',
    )
  }

  if (process.argv.includes('--check-only')) return

  const builder = join(projectRoot, 'node_modules', '.bin', 'electron-builder')
  const builderEnvironment = { ...process.env }
  let signingKeychain

  if (rootCertificate) {
    console.log('Preparing an isolated ClearTone signing keychain...')
    signingKeychain = await createSigningKeychain(rootCertificate, certificatePassword, {
      requireDeveloperId: process.env.CLEARTONE_REQUIRE_DEVELOPER_ID === 'true',
    })
    delete builderEnvironment.CSC_LINK
    delete builderEnvironment.CSC_KEY_PASSWORD
    builderEnvironment.CSC_KEYCHAIN = signingKeychain.keychain
    builderEnvironment.CSC_NAME = signingKeychain.identityQualifier
  } else if (!certificate) {
    builderEnvironment.CSC_IDENTITY_AUTO_DISCOVERY = 'false'
  }

  const builderArguments = ['--config', 'electron-builder.yml', '--mac']
  if (targetArchitecture) builderArguments.push(`--${targetArchitecture}`)
  if (signingKeychain?.usesDevelopmentSigning) {
    builderArguments.push('--config.mac.type=development')
  }
  builderArguments.push('--publish', 'never')

  try {
    const result = await new Promise((resolveChild, rejectChild) => {
      const child = spawn(builder, builderArguments, {
        cwd: appDirectory,
        env: builderEnvironment,
        stdio: 'inherit',
      })

      child.once('error', rejectChild)
      child.once('exit', (code, signal) => resolveChild({ code, signal }))
    })

    if (result.signal) {
      console.error(`electron-builder stopped after receiving ${result.signal}`)
      process.exitCode = 1
      return
    }

    process.exitCode = result.code ?? 1
  } catch (error) {
    console.error(
      `Could not start electron-builder: ${error instanceof Error ? error.message : error}`,
    )
    process.exitCode = 1
  } finally {
    await signingKeychain?.cleanup()
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error)
  process.exitCode = 1
})
