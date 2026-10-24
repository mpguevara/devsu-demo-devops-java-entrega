#requires -Version 7.2
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9._/:@-]+$')][string]$Image,
    [string]$EvidenceDirectory = (Join-Path $PSScriptRoot '../../target/security-evidence')
)

$ErrorActionPreference = 'Stop'
$evidence = [IO.Path]::GetFullPath($EvidenceDirectory)
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$started = [DateTimeOffset]::UtcNow
$scanExitCode = $null
$failure = $null
$findings = @()
$trivy = $null
try {
    $trivy = & (Join-Path $PSScriptRoot 'Install-Trivy.ps1')
    $jsonPath = Join-Path $evidence 'trivy-image.json'
    # Informativo por el stack heredado. No se omiten CVE sin correccion ni severidades.
    # --exit-code 0 solo controla hallazgos; errores operativos siguen siendo errores.
    & $trivy image --image-src docker --scanners vuln --timeout 10m --exit-code 0 `
        --format json --output $jsonPath $Image 2>&1 | Tee-Object -FilePath (Join-Path $evidence 'trivy.log')
    $scanExitCode = $LASTEXITCODE
    if ($scanExitCode -ne 0) { throw "Trivy no completo el escaneo (codigo $scanExitCode)." }
    $report = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
    $findings = @($report.Results | ForEach-Object { @($_.Vulnerabilities) } | Where-Object { $null -ne $_ })
    $counts = [ordered]@{}
    foreach ($severity in @('CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'UNKNOWN')) {
        $counts[$severity] = @($findings | Where-Object { $_.Severity -eq $severity }).Count
    }
    $lines = @(
        '# Resultado real de Trivy', '', "Imagen: $Image", '',
        'Politica del ejercicio: hallazgos informativos; un error del escaner bloquea el pipeline.',
        'No se afirma que la imagen sea segura o este libre de vulnerabilidades.', '',
        '| Severidad | Hallazgos |', '|---|---:|'
    )
    foreach ($severity in $counts.Keys) { $lines += "| $severity | $($counts[$severity]) |" }
    $lines += @('', 'El JSON completo conserva vulnerabilidades, versiones instaladas y versiones corregidas cuando existen.')
    $lines | Set-Content -LiteralPath (Join-Path $evidence 'trivy-summary.md') -Encoding utf8
} catch {
    $failure = $_.Exception.Message
} finally {
    [ordered]@{
        startedAt = $started.ToString('o'); finishedAt = [DateTimeOffset]::UtcNow.ToString('o')
        scanner = 'Trivy 0.76.1'; image = $Image; exitCode = $scanExitCode
        completed = $scanExitCode -eq 0; policy = 'report-all-findings; fail-on-scanner-error'
        findings = $findings.Count; bySeverity = $counts; failure = $failure
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidence 'scan-summary.json') -Encoding utf8
}
if ($failure) { throw $failure }
Write-Output "Escaneo completo: $($findings.Count) hallazgos. Consulta trivy-image.json; resultado informativo."
