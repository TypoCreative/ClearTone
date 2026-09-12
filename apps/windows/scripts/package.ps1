[CmdletBinding()]
param(
    [ValidateSet("x64", "arm64")]
    [string]$Architecture = "x64",
    [switch]$SkipBuild,
    [switch]$Sign,
    [string]$CertificatePath,
    [string]$TimestampUrl = "http://timestamp.digicert.com"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path
$Package = Get-Content (Join-Path $ProjectRoot "package.json") | ConvertFrom-Json
$Output = Join-Path $ProjectRoot "dist/windows/ClearTone"
$ArtifactKind = if ($Sign) { "signed" } else { "unsigned" }
$Archive = Join-Path $ProjectRoot "dist/ClearTone-$($Package.version)-windows-$Architecture-$ArtifactKind.zip"

if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot "build.ps1") -Configuration Release -Architecture $Architecture
}

if (-not (Test-Path (Join-Path $Output "ClearTone.exe"))) {
    throw "Build output is missing. Run build.ps1 before packaging."
}

$Executable = Join-Path $Output "ClearTone.exe"
if ($Sign) {
    if (-not $CertificatePath -or -not (Test-Path $CertificatePath)) {
        throw "A valid -CertificatePath is required for a signed Windows build."
    }
    if (-not $env:CLEARTONE_WINDOWS_CERTIFICATE_PASSWORD) {
        throw "Set CLEARTONE_WINDOWS_CERTIFICATE_PASSWORD; the password is never passed on the command line."
    }
    $SignTool = Get-Command "signtool.exe" -ErrorAction SilentlyContinue
    if (-not $SignTool) {
        throw "signtool.exe is required. Install the Windows SDK Signing Tools component."
    }

    $StoreName = "ClearToneSigning-$PID"
    $StorePath = "Cert:\CurrentUser\$StoreName"
    try {
        New-Item $StorePath -ErrorAction Stop | Out-Null
        $SecurePassword = ConvertTo-SecureString $env:CLEARTONE_WINDOWS_CERTIFICATE_PASSWORD -AsPlainText -Force
        $ImportedCertificates = Import-PfxCertificate -FilePath $CertificatePath -CertStoreLocation $StorePath -Password $SecurePassword
        $SigningCertificate = $ImportedCertificates | Where-Object {
            $_.HasPrivateKey -and ($_.EnhancedKeyUsageList.ObjectId.Value -contains "1.3.6.1.5.5.7.3.3")
        } | Select-Object -First 1
        $env:CLEARTONE_WINDOWS_CERTIFICATE_PASSWORD = $null

        if (-not $SigningCertificate) {
            throw "The PFX does not contain a code-signing identity with its private key."
        }
        & $SignTool.Source sign /fd SHA256 /td SHA256 /tr $TimestampUrl /s $StoreName /sha1 $SigningCertificate.Thumbprint $Executable
        if ($LASTEXITCODE -ne 0) {
            throw "Windows Authenticode signing failed."
        }
        & $SignTool.Source verify /pa /v $Executable
        if ($LASTEXITCODE -ne 0) {
            throw "Windows Authenticode verification failed."
        }
        $Signature = Get-AuthenticodeSignature $Executable
        if ($Signature.Status -ne "Valid") {
            throw "Expected a valid Windows signature, got: $($Signature.Status)"
        }
    } finally {
        $env:CLEARTONE_WINDOWS_CERTIFICATE_PASSWORD = $null
        if (Test-Path $StorePath) {
            Remove-Item $StorePath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

if (Test-Path $Archive) {
    Remove-Item $Archive -Force
}
Compress-Archive -Path (Join-Path $Output "*") -DestinationPath $Archive -CompressionLevel Optimal

if (-not (Test-Path $Archive)) {
    throw "Windows archive was not produced: $Archive"
}
Write-Host "Packaged $Archive"
