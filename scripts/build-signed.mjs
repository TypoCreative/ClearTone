#!/usr/bin/env node

import { chmodSync, existsSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, isAbsolute, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import process from "node:process";
import { fileURLToPath } from "node:url";

const projectRoot = resolve(import.meta.dirname, "..");
const temporaryDirectories = [];

function fail(message) {
  throw new Error(message);
}

function run(command, args, environment) {
  const result = spawnSync(command, args, {
    cwd: projectRoot,
    env: environment,
    stdio: "inherit",
  });
  if (result.error) fail(result.error.message);
  if (result.status !== 0) {
    const error = new Error(`${command} failed with exit code ${result.status ?? 1}.`);
    error.exitCode = result.status ?? 1;
    error.alreadyReported = true;
    throw error;
  }
}

function certificatePath(value, fallbackPath, extension) {
  const candidate = value?.startsWith("file://")
    ? fileURLToPath(value)
    : value;
  const localPath = candidate && (isAbsolute(candidate) ? candidate : resolve(projectRoot, candidate));
  if (localPath && existsSync(localPath)) return localPath;
  if (!candidate && fallbackPath && existsSync(fallbackPath)) return fallbackPath;
  if (!candidate) return null;

  let certificate;
  try {
    certificate = Buffer.from(candidate.replace(/\s/g, ""), "base64");
  } catch {
    return null;
  }
  if (certificate.length < 128) return null;
  const directory = mkdtempSync(join(tmpdir(), "cleartone-signing-"));
  temporaryDirectories.push(directory);
  const path = join(directory, `certificate.${extension}`);
  writeFileSync(path, certificate, { mode: 0o600 });
  return path;
}

async function secret(label, existingValue) {
  if (existingValue) return existingValue;
  if (!process.stdin.isTTY || !process.stdin.setRawMode) {
    fail(`${label} must be provided through an environment variable in CI.`);
  }

  process.stdout.write(`${label}: `);
  process.stdin.setEncoding("utf8");
  process.stdin.setRawMode(true);
  process.stdin.resume();
  return await new Promise((resolveSecret, rejectSecret) => {
    let value = "";
    const finish = () => {
      process.stdin.off("data", onData);
      process.stdin.setRawMode(false);
      process.stdin.pause();
      process.stdout.write("\n");
    };
    const onData = (input) => {
      for (const character of input) {
        if (character === "\u0003") {
          finish();
          const error = new Error("Build cancelled.");
          error.exitCode = 130;
          rejectSecret(error);
          return;
        }
        if (character === "\r" || character === "\n") {
          finish();
          resolveSecret(value);
          return;
        }
        if (character === "\u007f" || character === "\b") {
          value = value.slice(0, -1);
        } else {
          value += character;
        }
      }
    };
    process.stdin.on("data", onData);
  });
}

let completed = false;
try {
  if (process.platform === "darwin") {
    const path = join(projectRoot, "_dev-id-apple.p12");
    if (!existsSync(path) && !process.env.CLEARTONE_APP_SIGN_IDENTITY) {
      fail("Provide _dev-id-apple.p12 or CLEARTONE_APP_SIGN_IDENTITY for app signing.");
    }
    if (existsSync(path)) chmodSync(path, 0o600);
    run("npm", ["run", "dist:mac"], process.env);
  } else if (process.platform === "win32") {
    const path = certificatePath(
      process.env.WINDOWS_CERTIFICATE_PFX ?? process.env.WIN_CSC_LINK,
      null,
      "pfx",
    );
    if (!path) {
      fail("Set WINDOWS_CERTIFICATE_PFX (path or base64) to a Windows code-signing certificate.");
    }
    const password = await secret(
      "Password certificate Windows PFX",
      process.env.WINDOWS_CERTIFICATE_PASSWORD ?? process.env.WIN_CSC_KEY_PASSWORD,
    );
    if (!password) fail("The Windows certificate password cannot be empty.");
    run(
      "powershell.exe",
      [
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        join(projectRoot, "apps/windows/scripts/package.ps1"),
        "-Sign",
        "-CertificatePath",
        path,
      ],
      { ...process.env, CLEARTONE_WINDOWS_CERTIFICATE_PASSWORD: password },
    );
  } else {
    fail(`Signed desktop builds are supported only on macOS and Windows, not ${process.platform}.`);
  }
  completed = true;
} catch (error) {
  if (!error.alreadyReported) console.error(`ERR // ${error.message}`);
  process.exitCode = error.exitCode ?? 1;
} finally {
  for (const directory of temporaryDirectories) {
    rmSync(directory, { recursive: true, force: true });
  }
}

if (completed) {
  console.log(`Signed ClearTone release completed on ${basename(process.platform)}.`);
}
