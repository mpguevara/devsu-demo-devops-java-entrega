# Instalacion portable fuera del repositorio; no requiere administrador.
[CmdletBinding()]
param(
    [string]$ToolDirectory = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.cache/devsu-demo-tools/kind/v0.33.0'),
    [string]$EvidenceDirectory = (Join-Path $PSScriptRoot '../target/kind-install-evidence')
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Se requiere PowerShell 7.' }
$platform = if ($IsWindows) { 'windows' } elseif ($IsLinux) { 'linux' } else { throw 'Se admiten Windows y Linux.' }
$architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
$architecture = switch ($architecture) { 'x64' { 'amd64' }; 'arm64' { 'arm64' }; default { throw 'Arquitectura no admitida.' } }
$checksums = @{
    'windows-amd64' = '4b22adaa135368c5a465d56bbd8e520cbea87272a06ca00b6078e7b81515c9fc'
    'linux-amd64' = 'aee6151561422756b764a4ae28e7f44cda5af5a9eead3cc9985112b1de8d8e0d'
    'linux-arm64' = '20022bee6cfcd5086cb7234d218e3454e6090022f2a8f55d1fa7fcf42c3867a2'
}
$key = "$platform-$architecture"
if (-not $checksums.ContainsKey($key)) { throw "No hay binario kind fijado para $key." }
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$absoluteTools = [IO.Path]::GetFullPath($ToolDirectory)
if ($absoluteTools.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'ToolDirectory debe estar fuera del repositorio.'
}
New-Item -ItemType Directory -Path $absoluteTools -Force | Out-Null
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
$binary = Join-Path $absoluteTools $(if ($IsWindows) { 'kind.exe' } else { 'kind' })
$uri = "https://github.com/kubernetes-sigs/kind/releases/download/v0.33.0/kind-$key"
$checksumUri = "$uri.sha256sum"
$officialChecksum = (Invoke-WebRequest -Uri $checksumUri).Content
if ($officialChecksum -is [byte[]]) { $officialChecksum = [Text.Encoding]::UTF8.GetString($officialChecksum) }
$officialHash = ([string]$officialChecksum).Trim().Split(' ')[0].ToLowerInvariant()
if ($officialHash -cne $checksums[$key]) { throw 'El checksum publicado no coincide con el checksum fijado.' }
if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) {
    $download = Join-Path $absoluteTools ('kind-download-' + [Guid]::NewGuid().ToString('N'))
    try {
        Invoke-WebRequest -Uri $uri -OutFile $download
        if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant() -cne $officialHash) {
            throw 'SHA-256 incorrecto al descargar kind.'
        }
        Move-Item -LiteralPath $download -Destination $binary
    } finally {
        if (Test-Path -LiteralPath $download -PathType Leaf) { Remove-Item -LiteralPath $download }
    }
}
$actualHash = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -cne $officialHash) { throw 'El kind existente no coincide; no se reemplazara.' }
if (-not $IsWindows) { & chmod 0755 $binary; if ($LASTEXITCODE -ne 0) { throw 'No se pudo dar permiso de ejecucion a kind.' } }
$version = (& $binary version) -join "`n"
if ($LASTEXITCODE -ne 0 -or $version -notmatch '^kind v0\.33\.0 ') { throw 'La version kind ejecutada no coincide.' }
$env:PATH = $absoluteTools + [IO.Path]::PathSeparator + $env:PATH
[ordered]@{
    verifiedAt = [DateTimeOffset]::Now.ToString('o'); version = 'v0.33.0'; platform = $key
    source = $uri; checksumSource = $checksumUri; sha256 = $actualHash; binary = $binary
    versionOutput = $version; passed = $true
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'kind-install.json') -Encoding utf8
Write-Output "kind v0.33.0 verificado en $binary. PATH actualizado solo para el proceso actual."
