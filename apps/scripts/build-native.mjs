import { chmod, copyFile, mkdir } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(scriptDirectory, "../..");
const nativeProject = resolve(projectRoot, "native/swift-engine");
const destinationBinary = resolve(projectRoot, "apps/resources/native/ClearToneEngine");
const requestedArchitecture = process.env.CLEARTONE_TARGET_ARCH;
const swiftArchitecture = requestedArchitecture === "x64"
  ? "x86_64"
  : requestedArchitecture === "arm64"
    ? "arm64"
    : undefined;

if (requestedArchitecture && !swiftArchitecture) {
  throw new Error(
    `Unsupported CLEARTONE_TARGET_ARCH: ${requestedArchitecture}. Expected x64 or arm64.`,
  );
}

const buildArguments = ["build", "--disable-sandbox", "-c", "release"];
if (swiftArchitecture) buildArguments.push("--arch", swiftArchitecture);

execFileSync("swift", buildArguments, {
  cwd: nativeProject,
  stdio: "inherit"
});

const binaryPathArguments = [...buildArguments, "--show-bin-path"];
const binaryDirectory = execFileSync("swift", binaryPathArguments, {
  cwd: nativeProject,
  encoding: "utf8",
}).trim();
const sourceBinary = join(binaryDirectory, "ClearToneEngine");

await mkdir(dirname(destinationBinary), { recursive: true });
await copyFile(sourceBinary, destinationBinary);
await chmod(destinationBinary, 0o755);
execFileSync("file", [destinationBinary], { stdio: "inherit" });
console.log(`Copied release engine to ${destinationBinary}`);
