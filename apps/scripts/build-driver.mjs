import { chmod, cp, mkdir, mkdtemp, readFile, rm } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(scriptDirectory, "../..");
const driverProject = resolve(projectRoot, "native/virtual-microphone-driver");
const resourcesDirectory = resolve(projectRoot, "apps/resources/driver");
const driverName = "ClearToneVirtualMicrophone.driver";
const packageName = "ClearToneVirtualMicrophone.pkg";
const workspace = await mkdtemp(join(tmpdir(), "cleartone-driver-"));
const derivedData = join(workspace, "DerivedData");
const packageRoot = join(workspace, "package-root");
const builtDriver = join(derivedData, "Build/Products/Release", driverName);
const stagedDriver = join(packageRoot, "Library/Audio/Plug-Ins/HAL", driverName);
const resourcePackage = join(resourcesDirectory, packageName);
const packageJson = JSON.parse(await readFile(resolve(projectRoot, "package.json"), "utf8"));

try {
  execFileSync(
    "xcodebuild",
    [
      "-project",
      join(driverProject, "ClearToneVirtualMicrophone.xcodeproj"),
      "-scheme",
      "ClearToneVirtualMicrophone",
      "-configuration",
      "Release",
      "-derivedDataPath",
      derivedData,
      "CODE_SIGNING_ALLOWED=NO",
      "build"
    ],
    { cwd: driverProject, stdio: "inherit" }
  );

  execFileSync("xattr", ["-cr", builtDriver], { stdio: "inherit" });
  const driverIdentity = process.env.CLEARTONE_DRIVER_SIGN_IDENTITY ?? "-";
  const codesignArguments = ["--force", "--sign", driverIdentity];
  if (driverIdentity !== "-") codesignArguments.push("--timestamp", "--options", "runtime");
  codesignArguments.push(builtDriver);
  execFileSync("codesign", codesignArguments, { stdio: "inherit" });

  await mkdir(dirname(stagedDriver), { recursive: true });
  await mkdir(resourcesDirectory, { recursive: true });
  await cp(builtDriver, stagedDriver, { recursive: true });
  execFileSync("xattr", ["-cr", packageRoot], { stdio: "inherit" });
  await rm(resourcePackage, { force: true });

  const packageArguments = [
    "--root",
    packageRoot,
    "--identifier",
    "com.typocreative.cleartone.virtual-microphone.installer",
    "--version",
    packageJson.version,
    "--install-location",
    "/",
    "--scripts",
    join(driverProject, "Scripts")
  ];
  if (process.env.CLEARTONE_INSTALLER_SIGN_IDENTITY) {
    packageArguments.push("--sign", process.env.CLEARTONE_INSTALLER_SIGN_IDENTITY);
  }
  packageArguments.push(resourcePackage);
  execFileSync("pkgbuild", packageArguments, {
    env: { ...process.env, COPYFILE_DISABLE: "1" },
    stdio: "inherit"
  });
  await chmod(resourcePackage, 0o644);

  console.log(`Built virtual microphone driver and installer in ${resourcesDirectory}`);
} finally {
  await rm(workspace, { recursive: true, force: true });
}
