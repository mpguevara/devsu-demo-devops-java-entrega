#requires -Version 7.2
# Compara los bytes de cada dependencia empaquetada con el SBOM; no ejecuta Java ni Trivy.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$JarPath,
    [Parameter(Mandatory)][string]$SbomPath,
    [string]$TrivyReportPath,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [ValidatePattern('^[a-z0-9-]+$')][string]$EvidenceName = 'sbom-inventory',
    [ValidateSet('image-extracted-artifacts', 'unit-test-fixture')][string]$EvidenceSource = 'image-extracted-artifacts'
)
$ErrorActionPreference = 'Stop'
$directory = [IO.Path]::GetFullPath($EvidenceDirectory)
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$required = @(
    'ch.qos.logback:logback-classic', 'ch.qos.logback:logback-core',
    'com.fasterxml.jackson.core:jackson-core', 'com.fasterxml.jackson.core:jackson-databind',
    'com.h2database:h2', 'io.micrometer:micrometer-core',
    'org.apache.tomcat.embed:tomcat-embed-core', 'org.springframework.boot:spring-boot-actuator-autoconfigure',
    'org.springframework.boot:spring-boot-autoconfigure', 'org.springframework:spring-core',
    'org.springframework:spring-expression', 'org.springframework:spring-web',
    'org.springframework:spring-webmvc', 'org.yaml:snakeyaml'
)
function Normalize-Purl([string]$Purl) {
    return [Uri]::UnescapeDataString(($Purl -split '[?#]', 2)[0])
}
$jars = [Collections.Generic.List[object]]::new()
$historical = [Collections.Generic.List[object]]::new()
$missingInScan = [Collections.Generic.List[string]]::new()
$failure = $null
$passed = $false
$components = @()
$scannedPackages = @()
try {
    $bom = Get-Content -LiteralPath $SbomPath -Raw | ConvertFrom-Json
    if ($bom.bomFormat -ne 'CycloneDX' -or $bom.components -isnot [Array]) { throw 'SBOM CycloneDX invalido o sin componentes.' }
    $components = @($bom.components | Where-Object { $_.purl -like 'pkg:maven/*' })
    if ($components.Count -eq 0) { throw 'El SBOM no contiene coordenadas Maven.' }
    $hashIndex = @{}
    foreach ($component in $components) {
        foreach ($hash in @($component.hashes | Where-Object { $_.alg -eq 'SHA-256' })) {
            $value = ([string]$hash.content).ToLowerInvariant()
            if ($value -match '^[a-f0-9]{64}$') {
                if (-not $hashIndex.ContainsKey($value)) { $hashIndex[$value] = @() }
                $hashIndex[$value] += $component
            }
        }
    }
    $archive = [IO.Compression.ZipFile]::OpenRead((Get-Item -LiteralPath $JarPath).FullName)
    try {
        foreach ($entry in $archive.Entries | Where-Object { $_.FullName -match '^BOOT-INF/lib/[^/]+\.jar$' }) {
            $stream = $entry.Open()
            $hasher = [Security.Cryptography.SHA256]::Create()
            try { $hash = [Convert]::ToHexString($hasher.ComputeHash($stream)).ToLowerInvariant() }
            finally { $hasher.Dispose(); $stream.Dispose() }
            $componentMatches = @($hashIndex[$hash] | Where-Object { $null -ne $_ })
            $jars.Add([ordered]@{
                path = $entry.FullName; sha256 = $hash; matched = $componentMatches.Count -gt 0
                coordinates = @($componentMatches | ForEach-Object { "$($_.group):$($_.name):$($_.version)" })
                purls = @($componentMatches | ForEach-Object { Normalize-Purl $_.purl })
            })
        }
    } finally { $archive.Dispose() }
    if ($jars.Count -eq 0) { throw 'No hay dependencias BOOT-INF/lib para verificar.' }
    foreach ($coordinate in $required) {
        $parts = $coordinate.Split(':', 2)
        $coordinateMatches = @($components | Where-Object { $_.group -ceq $parts[0] -and $_.name -ceq $parts[1] })
        $historical.Add([ordered]@{ coordinate = $coordinate; present = $coordinateMatches.Count -gt 0
            versions = @($coordinateMatches.version); scanned = $null })
    }
    if ($TrivyReportPath) {
        $scan = Get-Content -LiteralPath $TrivyReportPath -Raw | ConvertFrom-Json
        if ($scan.SchemaVersion -ne 2 -or $scan.Results -isnot [Array]) { throw 'El inventario Trivy no tiene formato valido.' }
        $scannedPackages = @($scan.Results | ForEach-Object { $_.Packages } | Where-Object { $null -ne $_ })
        $scannedPurls = @($scannedPackages | ForEach-Object { Normalize-Purl $_.Identifier.PURL } | Where-Object { $_ })
        foreach ($purl in @($jars | ForEach-Object { $_.purls } | Sort-Object -Unique)) {
            if ($purl -cnotin $scannedPurls) { $missingInScan.Add($purl) }
        }
        foreach ($target in $historical) {
            $parts = $target.coordinate.Split(':', 2)
            $prefix = "pkg:maven/$($parts[0])/$($parts[1])@"
            $target.scanned = @($scannedPurls | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) }).Count -gt 0
        }
    }
    $unmatched = @($jars | Where-Object { -not $_.matched }).Count
    $missingHistorical = @($historical | Where-Object { -not $_.present -or ($TrivyReportPath -and -not $_.scanned) }).Count
    if ($unmatched -gt 0 -or $missingHistorical -gt 0 -or $missingInScan.Count -gt 0) {
        throw "Cobertura incompleta: $unmatched JAR sin hash SBOM, $missingHistorical coordenadas historicas ausentes, $($missingInScan.Count) PURL empaquetados sin inventario Trivy."
    }
    $passed = $true
} catch { $failure = $_.Exception.Message }
[ordered]@{
    checkedAt = [DateTimeOffset]::UtcNow.ToString('o'); source = $EvidenceSource; passed = $passed; failure = $failure
    jarSHA256 = if (Test-Path -LiteralPath $JarPath) { (Get-FileHash -LiteralPath $JarPath -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null }
    sbomSHA256 = if (Test-Path -LiteralPath $SbomPath) { (Get-FileHash -LiteralPath $SbomPath -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null }
    packagedJars = $jars.Count; jarsMatchedBySHA256 = @($jars | Where-Object { $_.matched }).Count
    sbomMavenComponents = $components.Count; scannerInventoryChecked = [bool]$TrivyReportPath
    scannedPackageRecords = $scannedPackages.Count; missingPackagedPurlsInScan = $missingInScan.ToArray()
    historicalCoordinates = $historical.ToArray(); jars = $jars.ToArray()
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $directory "$EvidenceName.json") -Encoding utf8
if (-not $passed) { throw $failure }
Write-Output "Inventario verificado: $($jars.Count) JAR por SHA256 y 14 coordenadas historicas; inventario Trivy comprobado=$([bool]$TrivyReportPath)."
