#requires -Version 7.2
[CmdletBinding()]
param([string]$EvidenceDirectory = (Join-Path $PSScriptRoot '../../.devsu-local/quality-evidence'))

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$evidence = [IO.Path]::GetFullPath($EvidenceDirectory)
$target = Join-Path $project 'target'
if ($evidence -eq $target -or $evidence.StartsWith($target + [IO.Path]::DirectorySeparatorChar)) {
    throw 'Guarda EvidenceDirectory fuera de target: Maven clean elimina ese directorio.'
}
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$started = [DateTimeOffset]::UtcNow
$exitCode = $null
$failure = $null
$previousLocation = Get-Location
try {
    Set-Location $project
    $java = (& java -version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $java -notmatch 'version "17\.') { throw 'Selecciona un JDK Java 17 antes de ejecutar calidad.' }
    $wrapper = if ($IsWindows) { Join-Path $project 'mvnw.cmd' } else { Join-Path $project 'mvnw' }
    if (-not $IsWindows) { & chmod +x $wrapper; if ($LASTEXITCODE -ne 0) { throw 'No se pudo habilitar mvnw.' } }
    # Un ciclo Maven incluye compilacion, pruebas, empaquetado, PMD y JaCoCo.
    & $wrapper -B -ntp clean verify '-DargLine=-Xmx384m' 2>&1 | Tee-Object -FilePath (Join-Path $evidence 'maven-verify.log')
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) { throw "Maven verify termino con codigo $exitCode." }
} catch {
    $failure = $_.Exception.Message
} finally {
    Set-Location $previousLocation
}

$tests = [ordered]@{ total = 0; failures = 0; errors = 0; skipped = 0 }
foreach ($report in @(Get-ChildItem -Path (Join-Path $target 'surefire-reports/TEST-*.xml') -ErrorAction SilentlyContinue)) {
    [xml]$xml = Get-Content -LiteralPath $report.FullName -Raw
    $tests.total += [int]$xml.testsuite.tests
    $tests.failures += [int]$xml.testsuite.failures
    $tests.errors += [int]$xml.testsuite.errors
    $tests.skipped += [int]$xml.testsuite.skipped
}
$coverage = @()
$jacocoPath = Join-Path $target 'site/jacoco/jacoco.xml'
if (Test-Path -LiteralPath $jacocoPath) {
    [xml]$jacoco = Get-Content -LiteralPath $jacocoPath -Raw
    $coverage = @($jacoco.report.counter | ForEach-Object {
        $total = [long]$_.covered + [long]$_.missed
        [ordered]@{ type = $_.type; covered = [long]$_.covered; missed = [long]$_.missed
            percent = if ($total -gt 0) { [Math]::Round(100.0 * [long]$_.covered / $total, 2) } else { $null } }
    })
}
$pmdViolations = $null
$pmdPath = Join-Path $target 'pmd.xml'
if (Test-Path -LiteralPath $pmdPath) {
    [xml]$pmd = Get-Content -LiteralPath $pmdPath -Raw
    $pmdViolations = @($pmd.SelectNodes('//*[local-name()="violation"]')).Count
}
$passed = $exitCode -eq 0 -and $tests.total -gt 0 -and $tests.failures -eq 0 -and $tests.errors -eq 0 `
    -and $coverage.Count -gt 0 -and $null -ne $pmdViolations
if (-not $passed -and -not $failure) { $failure = 'Faltan reportes reales de pruebas, JaCoCo o PMD.' }
[ordered]@{
    startedAt = $started.ToString('o'); finishedAt = [DateTimeOffset]::UtcNow.ToString('o')
    command = './mvnw -B -ntp clean verify -DargLine=-Xmx384m'; java = $java
    exitCode = $exitCode; passed = $passed; failure = $failure
    tests = $tests; coverage = $coverage; pmdViolations = $pmdViolations
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidence 'quality-summary.json') -Encoding utf8
if (-not $passed) { throw $failure }
Write-Output "Calidad aprobada: $($tests.total) pruebas; reportes JaCoCo y PMD generados."
