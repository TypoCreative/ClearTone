[CmdletBinding()]
param(
    [ValidateSet("Release", "Debug")]
    [string]$Configuration = "Release",
    [ValidateSet("x64", "arm64")]
    [string]$Architecture = "x64"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path
$Source = Join-Path $ProjectRoot "apps/windows/native"
$Build = Join-Path $ProjectRoot "build/windows/$Architecture"
$Output = Join-Path $ProjectRoot "dist/windows/ClearTone"

if (-not (Get-Command "cmake" -ErrorAction SilentlyContinue)) {
    throw "cmake is required. Install Visual Studio 2022 with Desktop development with C++."
}

if (Test-Path $Output) {
    Remove-Item $Output -Recurse -Force
}

cmake -S $Source -B $Build -G "Visual Studio 17 2022" -A $Architecture
cmake --build $Build --config $Configuration --parallel
cmake --install $Build --config $Configuration --prefix $Output

Write-Host "Built $Output/ClearTone.exe"
