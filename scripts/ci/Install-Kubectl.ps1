#requires -Version 7.2
[CmdletBinding()]
param(
    [string]$InstallDirectory = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.cache/devsu-demo-tools/kubectl/v1.36.4'),
    [string]$EvidenceDirectory = (Join-Path $PSScriptRoot '../../target/kubectl-install-evidence')
)

$ErrorActionPreference = 'Stop'
$version = 'v1.36.4'
if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne [Runtime.InteropServices.Architecture]::X64) {
    throw 'Este instalador fija kubectl Windows/Linux x64.'
}
if ($IsWindows) {
    $platform = 'windows'; $name = 'kubectl.exe'
    $expected = '31947857be7583f3e4e6d889a3fb781ca813a45c20f11ccb3ef309714d01a9f3'
} elseif ($IsLinux) {
    $platform = 'linux'; $name = 'kubectl'
    $expected = '8b8f088da2dab964f853b38464033b1be15ede2839eca751482357c45abdd05a'
} else { throw 'Se requiere Windows o Linux.' }
$directory = [IO.Path]::GetFullPath($InstallDirectory)
New-Item -ItemType Directory -Path $directory -Force | Out-Null
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
$binary = Join-Path $directory $name
$uri = "https://dl.k8s.io/release/$version/bin/$platform/amd64/$name"
if (-not (Test-Path -LiteralPath $binary)) { Invoke-WebRequest -Uri $uri -OutFile $binary }
$actual = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -cne $expected) { throw 'El SHA256 de kubectl no coincide; no se ejecutara.' }
if (-not $IsWindows) {
    & chmod 0755 $binary
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo habilitar kubectl.' }
}
$reported = (& $binary version --client -o json) | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $reported.clientVersion.gitVersion -ne $version) { throw 'La version de kubectl no coincide.' }
$env:PATH = $directory + [IO.Path]::PathSeparator + $env:PATH
if ($env:GITHUB_PATH) { $directory | Add-Content -LiteralPath $env:GITHUB_PATH }
[ordered]@{
    verifiedAt = [DateTimeOffset]::UtcNow.ToString('o'); version = $version; platform = "$platform/amd64"
    source = $uri; checksumSource = "$uri.sha256"; sha256 = $actual; passed = $true
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'kubectl-install.json') -Encoding utf8
Write-Output "kubectl $version verificado. PATH actualizado para este proceso y para los siguientes pasos de Actions cuando corresponde."
