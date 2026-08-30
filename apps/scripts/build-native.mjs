import { chmod, copyFile, mkdir } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(scriptDirectory, "../..");
const nativeProject = resolve(projectRoot, "native/swift-engine");
const sourceBinary = resolve(nativeProject, ".build/release/ClearToneEngine");
const destinationBinary = resolve(projectRoot, "apps/resources/native/ClearToneEngine");

execFileSync("swift", ["build", "--disable-sandbox", "-c", "release"], {
  cwd: nativeProject,
  stdio: "inherit"
});

await mkdir(dirname(destinationBinary), { recursive: true });
await copyFile(sourceBinary, destinationBinary);
await chmod(destinationBinary, 0o755);
console.log(`Copied release engine to ${destinationBinary}`);
