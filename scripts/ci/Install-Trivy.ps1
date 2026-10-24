#requires -Version 7.2
[CmdletBinding()]
param([string]$InstallDirectory = (Join-Path $PSScriptRoot '../../.devsu-local/tools/trivy-0.76.1'))

$ErrorActionPreference = 'Stop'
$version = '0.76.1'
if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne [System.Runtime.InteropServices.Architecture]::X64) {
    throw 'El instalador fijado de Trivy soporta Windows/Linux x64.'
}
# SHA256 publicados por Aqua en trivy_0.76.1_checksums.txt; no ejecutar instaladores remotos.
if ($IsWindows) {
    $asset = "trivy_${version}_windows-64bit.zip"
    $expectedHash = '1051f49cb22d5284f43425f72aad9cda63ca12ceb92e7caa06903490c82dc9bf'
    $binaryName = 'trivy.exe'
} elseif ($IsLinux) {
    $asset = "trivy_${version}_Linux-64bit.tar.gz"
    $expectedHash = 'c7cbe3137fb8a48a17574bede3dd6beb16742d1e9772929940fc90082c39d9c0'
    $binaryName = 'trivy'
} else { throw 'Usa Windows o Linux para este pipeline.' }
$directory = [IO.Path]::GetFullPath($InstallDirectory)
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$archive = Join-Path $directory $asset
if (-not (Test-Path -LiteralPath $archive)) {
    Invoke-WebRequest -Uri "https://github.com/aquasecurity/trivy/releases/download/v$version/$asset" -OutFile $archive
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'El SHA256 del paquete Trivy no coincide con el publicado. No se ejecutara.'
}
if ($IsWindows) { Expand-Archive -LiteralPath $archive -DestinationPath $directory -Force }
else {
    & tar -xzf $archive -C $directory
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo extraer Trivy.' }
    & chmod +x (Join-Path $directory $binaryName)
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo habilitar Trivy.' }
}
$binary = Join-Path $directory $binaryName
$reportedVersion = (& $binary --version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $reportedVersion -notmatch 'Version:\s+0\.76\.1') { throw 'Trivy no informa la version fijada.' }
# Devuelve solo la ruta para que otros scripts no dependan del PATH de la maquina.
return $binary
