#requires -Version 7.2
# Pruebas unitarias sinteticas: no ejecutan Docker, Maven ni Trivy.
[CmdletBinding()]
param([string]$EvidenceDirectory = (Join-Path $PSScriptRoot '../../.devsu-local/sbom-inventory-tests'))
$ErrorActionPreference = 'Stop'
$directory = [IO.Path]::GetFullPath($EvidenceDirectory)
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$coordinates = @(
    'ch.qos.logback:logback-classic', 'ch.qos.logback:logback-core',
    'com.fasterxml.jackson.core:jackson-core', 'com.fasterxml.jackson.core:jackson-databind',
    'com.h2database:h2', 'io.micrometer:micrometer-core',
    'org.apache.tomcat.embed:tomcat-embed-core', 'org.springframework.boot:spring-boot-actuator-autoconfigure',
    'org.springframework.boot:spring-boot-autoconfigure', 'org.springframework:spring-core',
    'org.springframework:spring-expression', 'org.springframework:spring-web',
    'org.springframework:spring-webmvc', 'org.yaml:snakeyaml'
)
$results = [Collections.Generic.List[object]]::new()
foreach ($case in @('complete', 'missing-component', 'incorrect-hash', 'missing-scanned-purl')) {
    $caseDirectory = Join-Path $directory $case
    New-Item -ItemType Directory -Path $caseDirectory -Force | Out-Null
    $jar = Join-Path $caseDirectory 'fixture.zip'
    if (Test-Path -LiteralPath $jar) { Remove-Item -LiteralPath $jar }
    $components = [Collections.Generic.List[object]]::new()
    $packages = [Collections.Generic.List[object]]::new()
    $zip = [IO.Compression.ZipFile]::Open($jar, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($coordinate in $coordinates) {
            $parts = $coordinate.Split(':', 2)
            $bytes = [Text.Encoding]::UTF8.GetBytes("synthetic-unit-test:$coordinate")
            $entry = $zip.CreateEntry("BOOT-INF/lib/$($parts[1])-0.0.0-fixture.jar")
            $stream = $entry.Open()
            try { $stream.Write($bytes) } finally { $stream.Dispose() }
            $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
            $purl = "pkg:maven/$($parts[0])/$($parts[1])@0.0.0-fixture"
            $components.Add([ordered]@{ type = 'library'; group = $parts[0]; name = $parts[1]; version = '0.0.0-fixture'
                purl = $purl; hashes = @(@{ alg = 'SHA-256'; content = $hash }) })
            $packages.Add(@{ Name = $coordinate; Version = '0.0.0-fixture'; Identifier = @{ PURL = $purl } })
        }
    } finally { $zip.Dispose() }
    if ($case -eq 'missing-component') { $components.RemoveAt(0) }
    if ($case -eq 'incorrect-hash') { $components[0].hashes[0].content = '0' * 64 }
    if ($case -eq 'missing-scanned-purl') { $packages.RemoveAt(0) }
    $bom = Join-Path $caseDirectory 'bom.json'
    $report = Join-Path $caseDirectory 'trivy-fixture.json'
    @{ bomFormat = 'CycloneDX'; specVersion = '1.6'; components = $components.ToArray() } |
        ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $bom -Encoding utf8
    @{ SchemaVersion = 2; Results = @(@{ Packages = $packages.ToArray(); Vulnerabilities = @() }) } |
        ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $report -Encoding utf8
    $rejected = $false
    try {
        & (Join-Path $PSScriptRoot 'Assert-SbomInventory.ps1') -JarPath $jar -SbomPath $bom -TrivyReportPath $report `
            -EvidenceDirectory $caseDirectory -EvidenceSource 'unit-test-fixture' | Out-Null
    } catch { $rejected = $true }
    $evidencePath = Join-Path $caseDirectory 'sbom-inventory.json'
    $written = Test-Path -LiteralPath $evidencePath
    $summary = if ($written) { Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json } else { $null }
    $expectedPass = $case -eq 'complete'
    $passed = $written -and $summary.source -eq 'unit-test-fixture' -and $summary.passed -eq $expectedPass -and $rejected -ne $expectedPass
    $results.Add([ordered]@{ name = $case; passed = $passed; expectedAccepted = $expectedPass
        rejected = $rejected; reportWritten = $written; failure = $summary.failure })
}
$failed = @($results | Where-Object { -not $_.passed }).Count
[ordered]@{ executedAt = [DateTimeOffset]::UtcNow.ToString('o'); source = 'unit-test-fixture'
    scannerExecuted = $false; dockerExecuted = $false; tests = $results.Count; failures = $failed
    passed = $failed -eq 0; cases = $results.ToArray() } |
    ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $directory 'test-results.json') -Encoding utf8
if ($failed -gt 0) { throw "$failed pruebas unitarias de inventario fallaron. Consultar $directory." }
Write-Output "$($results.Count) pruebas offline de inventario aprobadas; sin ejecutar Trivy ni Docker."
