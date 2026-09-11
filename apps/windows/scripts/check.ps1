[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path

& (Join-Path $PSScriptRoot "build.ps1") -Configuration Release -Architecture x64

$Build = Join-Path $ProjectRoot "build/windows/x64"
ctest --test-dir $Build -C Release --output-on-failure

$Executable = Join-Path $ProjectRoot "dist/windows/ClearTone/ClearTone.exe"
if (-not (Test-Path $Executable)) {
    throw "Windows executable was not produced: $Executable"
}

$Bytes = [System.IO.File]::ReadAllBytes($Executable)
if ($Bytes.Length -lt 64 -or $Bytes[0] -ne 0x4D -or $Bytes[1] -ne 0x5A) {
    throw "ClearTone.exe does not have a valid DOS/PE header."
}
$PeOffset = [BitConverter]::ToInt32($Bytes, 0x3C)
if ($PeOffset -lt 0 -or ($PeOffset + 6) -gt $Bytes.Length) {
    throw "ClearTone.exe has an invalid PE header offset."
}
$Machine = [BitConverter]::ToUInt16($Bytes, $PeOffset + 4)
if ($Machine -ne 0x8664) {
    throw "ClearTone.exe is not a valid x64 PE executable."
}

$Signature = Get-AuthenticodeSignature $Executable
if ($Signature.Status -ne "NotSigned") {
    throw "Expected an unsigned Windows build, got: $($Signature.Status)"
}

Write-Host "Windows build passed; artifact is intentionally unsigned."
