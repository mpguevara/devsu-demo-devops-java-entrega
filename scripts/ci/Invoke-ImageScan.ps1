#requires -Version 7.2
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9._/:@-]+$')][string]$Image,
    [string]$EvidenceDirectory = (Join-Path $PSScriptRoot '../../target/security-evidence')
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$evidence = [IO.Path]::GetFullPath($EvidenceDirectory)
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$started = [DateTimeOffset]::UtcNow
$scanExitCode = $null
$failure = $null
$trivy = $null
$jsonPath = Join-Path $evidence 'trivy-image.json'
# Una carpeta reutilizada no debe permitir evaluar el JSON de otra ejecucion.
if (Test-Path -LiteralPath $jsonPath -PathType Leaf) {
    throw 'EvidenceDirectory ya contiene trivy-image.json; utiliza otra carpeta para conservar cada escaneo.'
}
"Inicio real de Trivy para $Image; $($started.ToString('o'))." |
    Set-Content -LiteralPath (Join-Path $evidence 'trivy.log') -Encoding utf8
try {
    $trivy = & (Join-Path $PSScriptRoot 'Install-Trivy.ps1')
    # Conservar todas las severidades y CVE sin correccion. El helper aplica el gate
    # sobre el JSON completo; exit-code 0 distingue hallazgos de errores del escaner.
    & $trivy image --image-src docker --scanners vuln --timeout 10m --exit-code 0 `
        --config= --ignorefile= --ignore-unfixed=false `
        --severity 'UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL' --ignore-status= --ignore-policy= `
        --format json --output $jsonPath $Image 2>&1 | Tee-Object -FilePath (Join-Path $evidence 'trivy.log') -Append
    $scanExitCode = $LASTEXITCODE
    if ($scanExitCode -ne 0) { $failure = "Trivy no completo el escaneo (codigo $scanExitCode)." }
} catch {
    $failure = $_.Exception.Message
    "Error operativo: $failure" | Add-Content -LiteralPath (Join-Path $evidence 'trivy.log')
} finally {
    if ($trivy) {
        try {
            # Despues del escaneo: conserva version y fechas reales de las bases
            # disponibles en la cache, sin actualizar ni simular esa metadata.
            $versionOutput = (& $trivy --version --format json 2> (Join-Path $evidence 'trivy-version.stderr.log') | Out-String).Trim()
            $versionExitCode = $LASTEXITCODE
            $versionOutput | Set-Content -LiteralPath (Join-Path $evidence 'trivy-version.json') -Encoding utf8
            if ($versionExitCode -ne 0) { throw "No se pudo consultar metadata de Trivy (codigo $versionExitCode)." }
            $versionMetadata = $versionOutput | ConvertFrom-Json -ErrorAction Stop
            if ($versionMetadata.Version -ne '0.76.1') { throw 'La version registrada no coincide con Trivy 0.76.1.' }
        } catch {
            $metadataFailure = "Metadata del escaner: $($_.Exception.Message)"
            $failure = if ($failure) { "$failure $metadataFailure" } else { $metadataFailure }
            $metadataFailure | Add-Content -LiteralPath (Join-Path $evidence 'trivy.log')
        }
    }
    & (Join-Path $PSScriptRoot 'Assert-ImageScanPolicy.ps1') -Image $Image -JsonPath $jsonPath `
        -EvidenceDirectory $evidence -ScannerExitCode $scanExitCode -OperationalFailure $failure -StartedAt $started
}
Write-Output 'Escaneo completo y gate aprobado: 0 CRITICAL y 0 HIGH reportados. Consulta el JSON para las otras severidades.'
