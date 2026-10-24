#requires -Version 7.2
# Evalua un reporte ya producido. Este script no ejecuta Trivy ni descarga imagenes.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Image,
    [Parameter(Mandatory)][string]$JsonPath,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [Nullable[int]]$ScannerExitCode,
    [string]$OperationalFailure,
    [DateTimeOffset]$StartedAt = [DateTimeOffset]::UtcNow,
    [ValidateSet('trivy-real-scan', 'trivy-real-sbom-scan', 'unit-test-fixture')][string]$EvidenceSource = 'trivy-real-scan'
)

$ErrorActionPreference = 'Stop'
$evidence = [IO.Path]::GetFullPath($EvidenceDirectory)
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$completed = $null -ne $ScannerExitCode -and $ScannerExitCode -eq 0
$reportAvailable = Test-Path -LiteralPath $JsonPath -PathType Leaf
$assessmentSucceeded = $false
$status = 'operational-error'
$failureKind = 'operational'
$failure = $OperationalFailure
$counts = $null
$findings = $null
$blockingFindings = $null

if (-not $completed -or $OperationalFailure) {
    if (-not $failure) { $failure = "Trivy no termino correctamente (exitCode=$ScannerExitCode)." }
} else {
    try {
        if (-not $reportAvailable) { throw 'Trivy termino con codigo 0 pero no produjo un reporte JSON.' }
        $report = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
        if ($report.SchemaVersion -ne 2 -or $report.PSObject.Properties.Name -notcontains 'Results' -or
            $report.Results -isnot [Array]) {
            throw 'El reporte no contiene SchemaVersion 2 y un arreglo Results valido.'
        }
        $items = @($report.Results | ForEach-Object { @($_.Vulnerabilities) } | Where-Object { $null -ne $_ })
        $counts = [ordered]@{ CRITICAL = 0; HIGH = 0; MEDIUM = 0; LOW = 0; UNKNOWN = 0 }
        foreach ($item in $items) {
            if (-not $item.VulnerabilityID -or -not $item.PkgName -or -not $item.Severity -or
                -not $counts.Contains([string]$item.Severity)) {
                throw 'El reporte contiene una vulnerabilidad incompleta o una severidad desconocida.'
            }
            $counts[[string]$item.Severity]++
        }
        $findings = $items.Count
        $blockingFindings = $counts.CRITICAL + $counts.HIGH
        $assessmentSucceeded = $true
        if ($blockingFindings -gt 0) {
            $status = 'blocked-vulnerabilities'
            $failureKind = 'findings'
            $failure = "La politica bloquea $($counts.CRITICAL) CRITICAL y $($counts.HIGH) HIGH."
        } else {
            $status = 'passed'
            $failureKind = $null
            $failure = $null
        }
    } catch {
        $status = 'report-error'
        $failureKind = 'report'
        $failure = $_.Exception.Message
        # No presentar conteos parciales como un resultado evaluado correctamente.
        $counts = $null
        $findings = $null
        $blockingFindings = $null
    }
}

$gatePassed = $assessmentSucceeded -and $blockingFindings -eq 0
$summary = [ordered]@{
    startedAt = $StartedAt.ToString('o'); finishedAt = [DateTimeOffset]::UtcNow.ToString('o')
    source = $EvidenceSource; scanner = 'Trivy 0.76.1'; image = $Image; exitCode = $ScannerExitCode
    completed = $completed; reportAvailable = [bool]$reportAvailable; assessmentSucceeded = $assessmentSucceeded
    gatePassed = $gatePassed; status = $status; failureKind = $failureKind
    policy = 'block-any-critical-or-high; retain-all-severities; fail-closed-on-scan-or-report-error'
    blockedSeverities = @('CRITICAL', 'HIGH'); findings = $findings; blockingFindings = $blockingFindings
    bySeverity = $counts; failure = $failure
}
# Los tres archivos se escriben antes de devolver un error a CI.
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $evidence 'scan-summary.json') -Encoding utf8
$title = if ($EvidenceSource -eq 'unit-test-fixture') {
    '# Prueba unitaria de politica: fixture, sin ejecutar Trivy'
} else { '# Resultado real de Trivy y control de vulnerabilidades' }
$lines = @(
    $title, '', "Imagen: $Image", '',
    'Politica: cualquier CRITICAL o HIGH bloquea publicacion y despliegue. Se conservan todas las severidades.',
    "Estado: $status. Escaner completado: $completed. Evaluacion valida: $assessmentSucceeded. Gate aprobado: $gatePassed.", ''
)
if ($assessmentSucceeded) {
    $lines += @('| Severidad | Hallazgos |', '|---|---:|')
    foreach ($severity in $counts.Keys) { $lines += "| $severity | $($counts[$severity]) |" }
} else { $lines += 'No hay un conteo validado; consultar el error operativo o del reporte.' }
if ($failure) { $lines += @('', "Detalle: $failure") }
$lines += @('', 'Un gate aprobado solo confirma ausencia de CRITICAL/HIGH reportados en este escaneo y no demuestra ausencia de todo riesgo.')
$lines | Set-Content -LiteralPath (Join-Path $evidence 'trivy-summary.md') -Encoding utf8
$message = "Vulnerability policy: status=$status; completed=$completed; assessmentSucceeded=$assessmentSucceeded; gatePassed=$gatePassed."
$message | Set-Content -LiteralPath (Join-Path $evidence 'scan-policy.log') -Encoding utf8
Write-Output $message
if (-not $gatePassed) { throw "Control de vulnerabilidades rechazado ($status): $failure Evidencia: $evidence" }
