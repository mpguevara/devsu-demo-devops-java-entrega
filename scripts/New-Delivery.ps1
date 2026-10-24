[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot '../../devsu-demo-devops-java-entrega.zip')
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputFile = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path $outputFile -Parent
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    throw "El directorio de salida no existe: $outputDirectory"
}
if ([IO.Path]::GetExtension($outputFile) -ne '.zip') { throw 'La salida debe ser un archivo .zip.' }

Push-Location $projectRoot
try {
    $commit = (& git rev-parse --verify HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Se necesita un commit real antes de generar la entrega.' }
    $changes = @(& git status --porcelain --untracked-files=normal)
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar el estado Git.' }
    if ($changes.Count -gt 0) {
        throw 'Hay cambios sin versionar. Revisa y confirma los archivos antes de empaquetar HEAD.'
    }
    & git archive --format=zip --prefix=devsu-demo-devops-java/ "--output=$outputFile" HEAD
    if ($LASTEXITCODE -ne 0) { throw 'git archive no pudo crear la entrega.' }

    $archive = [IO.Compression.ZipFile]::OpenRead($outputFile)
    $entries = @()
    try {
        foreach ($entry in $archive.Entries) {
            $relative = $entry.FullName -replace '^devsu-demo-devops-java/', ''
            if (-not $relative -or $relative.EndsWith('/')) { continue }
            if ($relative -match '(^|/)(\.git|target|\.tools|\.devsu-local|node_modules|outputs|artifacts|delivery)(/|$)' -or
                $relative -match '(^|/)(\.env($|\.)|kubeconfig|secrets\.local\.)' -or
                $relative -match '\.(mv\.db|trace\.db|lock\.db|key|p12|kubeconfig)$') {
                throw "Archivo local o sensible no permitido en el paquete: $relative"
            }
            $stream = $entry.Open()
            $hasher = [Security.Cryptography.SHA256]::Create()
            try { $entryHash = [Convert]::ToHexString($hasher.ComputeHash($stream)).ToLowerInvariant() }
            finally { $hasher.Dispose(); $stream.Dispose() }
            $entries += [pscustomobject]@{ path=$relative; sizeBytes=$entry.Length; sha256=$entryHash }
        }
    } finally { $archive.Dispose() }

    $requiredPaths = @('Dockerfile','pom.xml','README.md','.mvn/wrapper/maven-wrapper.jar')
    foreach ($required in $requiredPaths) {
        if ($required -notin $entries.path) { throw "Falta un archivo requerido en la entrega: $required" }
    }
    $manifestPath = "$outputFile.manifest.json"
    [ordered]@{
        generatedAt=[DateTimeOffset]::Now.ToString('o')
        commit=$commit
        archiveName=[IO.Path]::GetFileName($outputFile)
        archiveSHA256=(Get-FileHash -LiteralPath $outputFile -Algorithm SHA256).Hash.ToLowerInvariant()
        fileCount=$entries.Count
        files=$entries
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    Write-Host "Entrega verificada: $($entries.Count) archivos de Git HEAD."
    Write-Host "ZIP: $outputFile"
    Write-Host "Manifiesto: $manifestPath"
} finally { Pop-Location }
