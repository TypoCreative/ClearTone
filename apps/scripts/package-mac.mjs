import { readdir } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { dirname, join, resolve } from 'node:path'
import { spawn, spawnSync } from 'node:child_process'

const scriptDirectory = dirname(fileURLToPath(import.meta.url))
const appDirectory = resolve(scriptDirectory, '..')
const projectRoot = resolve(appDirectory, '..')
const rootCertificateName = '_dev-id-apple.p12'

async function findRootCertificate() {
  const entries = await readdir(projectRoot, { withFileTypes: true })
  const certificate = entries.find(
    (entry) => entry.isFile() && entry.name === rootCertificateName,
  )

  if (!certificate) {
    throw new Error(
      `Missing macOS signing certificate: ${join(projectRoot, rootCertificateName)}. Add the file or set CSC_LINK explicitly.`,
    )
  }

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

  if (process.env.CSC_LINK) {
    console.log('Using macOS signing certificate from CSC_LINK.')
  } else if (rootCertificate) {
    console.log(`Using macOS signing certificate: ${rootCertificate}`)
  } else {
    console.warn('No local certificate selected; electron-builder will use its normal signing discovery.')
  }

  if (process.argv.includes('--check-only')) return

  const builder = join(projectRoot, 'node_modules', '.bin', 'electron-builder')
  const builderEnvironment = certificate ? { ...process.env, CSC_LINK: certificate } : { ...process.env }
  if (certificatePassword !== undefined) {
    builderEnvironment.CSC_KEY_PASSWORD = certificatePassword
  }

  const child = spawn(builder, ['--config', 'electron-builder.yml', '--mac', '--publish', 'never'], {
    cwd: appDirectory,
    env: builderEnvironment,
    stdio: 'inherit',
  })

  child.on('error', (error) => {
    console.error(`Could not start electron-builder: ${error.message}`)
    process.exitCode = 1
  })

  child.on('exit', (code, signal) => {
    if (signal) {
      console.error(`electron-builder stopped after receiving ${signal}`)
      process.exitCode = 1
      return
    }

    process.exitCode = code ?? 1
  })
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error)
  process.exitCode = 1
})
