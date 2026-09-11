[CmdletBinding()]
param(
    [ValidateSet("x64", "arm64")]
    [string]$Architecture = "x64",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path
$Package = Get-Content (Join-Path $ProjectRoot "package.json") | ConvertFrom-Json
$Output = Join-Path $ProjectRoot "dist/windows/ClearTone"
$Archive = Join-Path $ProjectRoot "dist/ClearTone-$($Package.version)-windows-$Architecture-unsigned.zip"

if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot "build.ps1") -Configuration Release -Architecture $Architecture
}

if (-not (Test-Path (Join-Path $Output "ClearTone.exe"))) {
    throw "Build output is missing. Run build.ps1 before packaging."
}

if (Test-Path $Archive) {
    Remove-Item $Archive -Force
}
Compress-Archive -Path (Join-Path $Output "*") -DestinationPath $Archive -CompressionLevel Optimal

if (-not (Test-Path $Archive)) {
    throw "Windows archive was not produced: $Archive"
}
Write-Host "Packaged $Archive"
