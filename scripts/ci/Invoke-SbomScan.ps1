#requires -Version 7.2
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9._/:@-]+$')][string]$Image,
    [string]$EvidenceDirectory = (Join-Path $PSScriptRoot '../../target/sbom-security-evidence')
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$evidence = [IO.Path]::GetFullPath($EvidenceDirectory)
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
if (@('bom.json', 'trivy-sbom.json', 'sbom-check-results.json') | Where-Object { Test-Path -LiteralPath (Join-Path $evidence $_) }) {
    throw 'Utiliza una carpeta nueva: la evidencia SBOM de una ejecucion anterior se conserva.'
}
$started = [DateTimeOffset]::UtcNow
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('devsu-sbom-' + [Guid]::NewGuid().ToString('N'))
$container = $null
$imageId = $null
$extracted = $false
$beforePassed = $false
$afterPassed = $false
$scanExecuted = $false
$scanExitCode = $null
$policyPassed = $false
$cleanupPassed = $false
$failure = $null
$trivy = $null
$bomPath = Join-Path $evidence 'bom.json'
$jarPath = Join-Path $temporary 'app.jar'
$jsonPath = Join-Path $evidence 'trivy-sbom.json'
$logPath = Join-Path $evidence 'trivy.log'
"Inicio de extraccion y escaneo SBOM real: $($started.ToString('o')); imagen $Image." | Set-Content -LiteralPath $logPath
try {
    New-Item -ItemType Directory -Path $temporary | Out-Null
    $imageId = (& docker image inspect --format '{{.Id}}' $Image | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $imageId -notmatch '^sha256:[a-f0-9]{64}$') { throw 'No se pudo identificar la imagen local.' }
    # create/cp no arrancan la aplicacion. Se usa el ID para evitar que un tag cambie entre operaciones.
    $container = (& docker create $imageId | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $container -notmatch '^[a-f0-9]{64}$') { throw 'No se pudo crear el contenedor temporal sin ejecutarlo.' }
    & docker cp "${container}:/app/sbom.json" $bomPath
    if ($LASTEXITCODE -ne 0) { throw 'La imagen no contiene /app/sbom.json.' }
    & docker cp "${container}:/app/app.jar" $jarPath
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo extraer /app/app.jar.' }
    $extracted = $true
    & (Join-Path $PSScriptRoot 'Assert-SbomInventory.ps1') -JarPath $jarPath -SbomPath $bomPath `
        -EvidenceDirectory $evidence -EvidenceName 'inventory-before-scan'
    $beforePassed = $true
    $trivy = & (Join-Path $PSScriptRoot 'Install-Trivy.ps1')
    $scanFailure = $null
    try {
        $scanExecuted = $true
        & $trivy sbom --scanners vuln --timeout 10m --exit-code 0 --config= --ignorefile= `
            --ignore-unfixed=false --severity 'UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL' --ignore-status= --ignore-policy= `
            --list-all-pkgs --format json --output $jsonPath $bomPath 2>&1 | Tee-Object -FilePath $logPath -Append
        $scanExitCode = $LASTEXITCODE
        if ($scanExitCode -ne 0) { $scanFailure = "Trivy SBOM no completo el escaneo (codigo $scanExitCode)." }
    } catch { $scanFailure = $_.Exception.Message }
    try {
        $version = (& $trivy --version --format json 2> (Join-Path $evidence 'trivy-version.stderr.log') | Out-String).Trim()
        $versionExit = $LASTEXITCODE
        $version | Set-Content -LiteralPath (Join-Path $evidence 'trivy-version.json') -Encoding utf8
        if ($versionExit -ne 0 -or ($version | ConvertFrom-Json).Version -ne '0.76.1') { throw 'Metadata de version Trivy no valida.' }
    } catch { $scanFailure = "$scanFailure Metadata: $($_.Exception.Message)".Trim() }
    # Aunque haya hallazgos, conservar y comprobar tambien el inventario que realmente analizo Trivy.
    $gateFailure = $null
    try {
        & (Join-Path $PSScriptRoot 'Assert-ImageScanPolicy.ps1') -Image $Image -JsonPath $jsonPath `
            -EvidenceDirectory $evidence -ScannerExitCode $scanExitCode -OperationalFailure $scanFailure `
            -StartedAt $started -EvidenceSource 'trivy-real-sbom-scan'
        $policyPassed = $true
    } catch { $gateFailure = $_.Exception.Message }
    if ($scanExitCode -eq 0 -and (Test-Path -LiteralPath $jsonPath)) {
        & (Join-Path $PSScriptRoot 'Assert-SbomInventory.ps1') -JarPath $jarPath -SbomPath $bomPath `
            -TrivyReportPath $jsonPath -EvidenceDirectory $evidence -EvidenceName 'inventory-after-scan'
        $afterPassed = $true
    }
    if ($gateFailure) { throw $gateFailure }
    if (-not $afterPassed) { throw 'No se pudo verificar el inventario escaneado.' }
} catch {
    $failure = $_.Exception.Message
    "Fallo: $failure" | Add-Content -LiteralPath $logPath
} finally {
    try {
        if ($container -match '^[a-f0-9]{64}$') {
            & docker rm $container 2>&1 | Add-Content -LiteralPath $logPath
            if ($LASTEXITCODE -ne 0) { throw 'No se pudo retirar el contenedor temporal propio.' }
        }
        $absolute = [IO.Path]::GetFullPath($temporary)
        $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
        if ([IO.Path]::GetDirectoryName($absolute) -ne $parent -or [IO.Path]::GetFileName($absolute) -notlike 'devsu-sbom-*') {
            throw 'La ruta temporal no coincide con el directorio propio.'
        }
        if (Test-Path -LiteralPath $absolute) { Remove-Item -LiteralPath $absolute -Recurse -Force }
        $cleanupPassed = $true
    } catch { $failure = "$failure Limpieza: $($_.Exception.Message)".Trim() }
    [ordered]@{
        startedAt = $started.ToString('o'); finishedAt = [DateTimeOffset]::UtcNow.ToString('o')
        source = 'image-extracted-artifacts-and-real-trivy-sbom'; image = $Image; imageId = $imageId
        extracted = $extracted; preScanInventoryPassed = $beforePassed; scannerExecuted = $scanExecuted
        scannerExitCode = $scanExitCode; vulnerabilityGatePassed = $policyPassed; scannedInventoryPassed = $afterPassed
        temporaryJarRemoved = $cleanupPassed; passed = $beforePassed -and $policyPassed -and $afterPassed -and $cleanupPassed
        failure = $failure
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidence 'sbom-check-results.json') -Encoding utf8
}
if ($failure) { throw $failure }
Write-Output 'SBOM de la imagen: todos los JAR por SHA256 y PURL verificados; 0 CRITICAL/HIGH reportados.'
