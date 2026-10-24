[CmdletBinding()]
param(
    [string]$ToolsDirectory = (Join-Path $env:LOCALAPPDATA 'DevsuDevOps\tools')
)

$ErrorActionPreference = 'Stop'
$release = 'jdk-17.0.20.1+1'
$archiveName = 'OpenJDK17U-jdk_x64_windows_hotspot_17.0.20.1_1.zip'
$expectedSHA256 = 'e53a79c3c3d86865bd7e787903884331068e71321714ffd44f145785affc7cb0'
$downloadUrl = 'https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.20.1%2B1/' + $archiveName
$jdkDirectory = Join-Path $ToolsDirectory $release
$archivePath = Join-Path $ToolsDirectory $archiveName

New-Item -ItemType Directory -Path $ToolsDirectory -Force | Out-Null
if (-not (Test-Path -LiteralPath $archivePath)) {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath -TimeoutSec 300
}

$actualSHA256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSHA256 -ne $expectedSHA256) {
    throw "El SHA-256 del JDK no coincide. Revisa el archivo: $archivePath"
}

if (-not (Test-Path -LiteralPath (Join-Path $jdkDirectory 'bin\javac.exe'))) {
    Expand-Archive -LiteralPath $archivePath -DestinationPath $ToolsDirectory
}

Write-Output "JDK portable: $jdkDirectory"
Write-Output "SHA-256 del ZIP verificado: $actualSHA256"
Write-Output 'Para seleccionarlo en esta terminal, ejecuta scripts\Use-Java17.ps1.'
