#requires -Version 7.2
# Pruebas unitarias offline de la politica. No ejecutan Trivy, Docker ni descargas.
[CmdletBinding()]
param([string]$EvidenceDirectory = (Join-Path $PSScriptRoot '../../.devsu-local/scan-policy-tests'))

$ErrorActionPreference = 'Stop'
$directory = [IO.Path]::GetFullPath($EvidenceDirectory)
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$started = [DateTimeOffset]::UtcNow
$tests = [Collections.Generic.List[object]]::new()
function New-Finding([string]$Severity) {
    return @{ VulnerabilityID = "FIXTURE-$Severity-001"; PkgName = 'fixture:library'
        InstalledVersion = '0.0.0-test'; FixedVersion = ''; Severity = $Severity }
}
$cases = @(
    @{ name = 'high-in-second-result-unfixed'; report = @{ SchemaVersion = 2; Results = @(
        @{ Target = 'fixture-os'; Vulnerabilities = @((New-Finding 'MEDIUM')) },
        @{ Target = 'fixture-java'; Vulnerabilities = @((New-Finding 'HIGH')) }
    ) }; code = 0; status = 'blocked-vulnerabilities'; completed = $true; assessed = $true; blocked = 1; throws = $true },
    @{ name = 'critical-unfixed'; report = @{ SchemaVersion = 2; Results = @(
        @{ Target = 'fixture-os'; Vulnerabilities = @((New-Finding 'CRITICAL')) }
    ) }; code = 0; status = 'blocked-vulnerabilities'; completed = $true; assessed = $true; blocked = 1; throws = $true },
    @{ name = 'medium-low-unknown-pass'; report = @{ SchemaVersion = 2; Results = @(
        @{ Target = 'fixture'; Vulnerabilities = @((New-Finding 'MEDIUM'), (New-Finding 'LOW'), (New-Finding 'UNKNOWN')) }
    ) }; code = 0; status = 'passed'; completed = $true; assessed = $true; blocked = 0; throws = $false },
    @{ name = 'empty-valid-report-pass'; report = @{ SchemaVersion = 2; Results = @() }
        code = 0; status = 'passed'; completed = $true; assessed = $true; blocked = 0; throws = $false },
    @{ name = 'scanner-process-failed'; report = @{ SchemaVersion = 2; Results = @() }
        code = 2; status = 'operational-error'; completed = $false; assessed = $false; blocked = $null; throws = $true },
    @{ name = 'invalid-json'; raw = '{"SchemaVersion":'; code = 0; status = 'report-error'
        completed = $true; assessed = $false; blocked = $null; throws = $true },
    @{ name = 'missing-report'; code = 0; status = 'report-error'
        completed = $true; assessed = $false; blocked = $null; throws = $true },
    @{ name = 'unsupported-severity-fails-closed'; report = @{ SchemaVersion = 2; Results = @(
        @{ Target = 'fixture'; Vulnerabilities = @((New-Finding 'INVALID')) }
    ) }; code = 0; status = 'report-error'; completed = $true; assessed = $false; blocked = $null; throws = $true }
)
foreach ($case in $cases) {
    $caseDirectory = Join-Path $directory $case.name
    New-Item -ItemType Directory -Path $caseDirectory -Force | Out-Null
    $inputPath = Join-Path $caseDirectory 'fixture-input.json'
    if (Test-Path -LiteralPath $inputPath) { Remove-Item -LiteralPath $inputPath }
    if ($case.ContainsKey('report')) {
        $case.report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $inputPath -Encoding utf8
    } elseif ($case.ContainsKey('raw')) { $case.raw | Set-Content -LiteralPath $inputPath -Encoding utf8 }
    $threw = $false
    $exception = $null
    try {
        & (Join-Path $PSScriptRoot 'Assert-ImageScanPolicy.ps1') -Image 'fixture/not-a-real-image:test' `
            -JsonPath $inputPath -EvidenceDirectory $caseDirectory -ScannerExitCode $case.code `
            -EvidenceSource unit-test-fixture | Out-Null
    } catch { $threw = $true; $exception = $_.Exception.Message }
    $errors = [Collections.Generic.List[string]]::new()
    $summaryPath = Join-Path $caseDirectory 'scan-summary.json'
    $reportWritten = (Test-Path $summaryPath) -and (Test-Path (Join-Path $caseDirectory 'trivy-summary.md')) `
        -and (Test-Path (Join-Path $caseDirectory 'scan-policy.log'))
    if (-not $reportWritten) { $errors.Add('No se conservaron todos los resultados antes del error.') }
    if ($threw -ne $case.throws) { $errors.Add('La excepcion no coincide con el resultado esperado del gate.') }
    $actual = $null
    if (Test-Path $summaryPath) {
        $actual = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
        if ($actual.status -ne $case.status) { $errors.Add('Estado incorrecto.') }
        if ($actual.completed -ne $case.completed) { $errors.Add('completed confunde finalizacion del escaner con el gate.') }
        if ($actual.assessmentSucceeded -ne $case.assessed) { $errors.Add('Evaluacion incorrecta.') }
        if ($actual.blockingFindings -ne $case.blocked) { $errors.Add('Conteo bloqueante incorrecto.') }
        if ($actual.gatePassed -ne (-not $case.throws)) { $errors.Add('gatePassed incorrecto.') }
        if ($actual.source -ne 'unit-test-fixture') { $errors.Add('El fixture no esta identificado como prueba unitaria.') }
        if (-not $case.assessed -and $null -ne $actual.findings) { $errors.Add('Un error no debe informar cero vulnerabilidades.') }
        if ($case.name -eq 'medium-low-unknown-pass' -and
            ($actual.findings -ne 3 -or $actual.bySeverity.MEDIUM -ne 1 -or $actual.bySeverity.LOW -ne 1 -or $actual.bySeverity.UNKNOWN -ne 1)) {
            $errors.Add('Se perdieron severidades no bloqueantes.')
        }
        if ($case.name -eq 'high-in-second-result-unfixed' -and ($actual.findings -ne 2 -or $actual.bySeverity.HIGH -ne 1)) {
            $errors.Add('No se evaluaron todos los resultados o se excluyeron hallazgos sin correccion.')
        }
    }
    $tests.Add([ordered]@{ name = $case.name; passed = $errors.Count -eq 0; expectedStatus = $case.status
        actualStatus = $actual.status; expectedThrow = $case.throws; actualThrow = $threw
        reportsWrittenBeforeReturn = $reportWritten; exception = $exception; errors = $errors.ToArray() })
}
$failed = @($tests | Where-Object { -not $_.passed }).Count
[ordered]@{
    startedAt = $started.ToString('o'); finishedAt = [DateTimeOffset]::UtcNow.ToString('o')
    executionType = 'offline policy unit tests with synthetic fixtures'; scannerExecuted = $false
    total = $tests.Count; passed = $tests.Count - $failed; failed = $failed; tests = $tests.ToArray()
} | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $directory 'policy-test-results.json') -Encoding utf8
if ($failed -gt 0) { throw "Fallaron $failed pruebas unitarias de politica. Evidencia: $directory" }
Write-Output "Politica verificada: $($tests.Count) pruebas unitarias offline aprobadas. No se ejecuto Trivy."
