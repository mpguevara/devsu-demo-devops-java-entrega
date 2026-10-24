#requires -Version 7.2
[CmdletBinding()]
param(
    [ValidatePattern('^[a-z0-9][a-z0-9._/:@-]+$')][string]$Image = ('devsu-demo-java:local-' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')),
    [ValidateSet('Quality', 'Image', 'Kubernetes')][string]$StopAfter = 'Kubernetes',
    [string]$EvidenceDirectory = (Join-Path $PSScriptRoot ('../../.devsu-local/pipeline-evidence/' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))),
    [ValidatePattern('^ghcr\.io/[a-z0-9][a-z0-9._/-]+:[a-z0-9][a-z0-9._-]+$')][string]$PublishImage
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$evidence = [IO.Path]::GetFullPath($EvidenceDirectory)
$target = Join-Path $project 'target'
if ($evidence -eq $target -or $evidence.StartsWith($target + [IO.Path]::DirectorySeparatorChar)) {
    throw 'EvidenceDirectory debe quedar fuera de target, que Maven clean elimina.'
}
if ($PublishImage -and $StopAfter -eq 'Quality') { throw 'Publicar requiere construir y analizar la imagen.' }
if ($PublishImage -and (-not $env:GHCR_USER -or -not $env:GHCR_TOKEN)) {
    throw 'Para -PublishImage define GHCR_USER y GHCR_TOKEN temporalmente en esta terminal.'
}
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$stages = [System.Collections.Generic.List[object]]::new()
$started = [DateTimeOffset]::UtcNow
$passed = $false
$failure = $null
$previousLocation = Get-Location

function Invoke-Stage {
    param([string]$Name, [scriptblock]$Action)
    $begin = [DateTimeOffset]::UtcNow
    $stagePassed = $false
    $stageFailure = $null
    try {
        Write-Output "Etapa: $Name"
        & $Action
        $stagePassed = $true
    } catch {
        $stageFailure = $_.Exception.Message
        # No registrar el token ni incluirlo en argumentos o mensajes de comandos.
        if ($env:GHCR_TOKEN) { $stageFailure = $stageFailure.Replace($env:GHCR_TOKEN, '[REDACTED]') }
        throw
    } finally {
        $stages.Add([ordered]@{
            name = $Name; startedAt = $begin.ToString('o'); finishedAt = [DateTimeOffset]::UtcNow.ToString('o')
            passed = $stagePassed; failure = $stageFailure
        })
    }
}

try {
    Set-Location $project
    Invoke-Stage 'compile-test-package-static-analysis-coverage' {
        & (Join-Path $PSScriptRoot 'Invoke-Quality.ps1') -EvidenceDirectory (Join-Path $evidence 'quality')
    }
    if ($StopAfter -ne 'Quality') {
        Invoke-Stage 'docker-build' {
            & docker version --format '{{.Server.Version}}'
            if ($LASTEXITCODE -ne 0) { throw 'Docker Engine no esta disponible.' }
            & docker build --progress plain --tag $Image . 2>&1 | Tee-Object -FilePath (Join-Path $evidence 'docker-build.log')
            if ($LASTEXITCODE -ne 0) { throw 'Fallo docker build.' }
            $imageId = & docker image inspect --format '{{.Id}}' $Image
            if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar la imagen construida.' }
            $user = & docker image inspect --format '{{.Config.User}}' $Image
            if ($LASTEXITCODE -ne 0 -or $user -ne '10001:10001') { throw 'La imagen debe ejecutar UID/GID 10001.' }
            @{ image = $Image; imageId = $imageId; user = $user } | ConvertTo-Json |
                Set-Content -LiteralPath (Join-Path $evidence 'image.json') -Encoding utf8
        }
        Invoke-Stage 'vulnerability-report' {
            & (Join-Path $PSScriptRoot 'Invoke-ImageScan.ps1') -Image $Image -EvidenceDirectory (Join-Path $evidence 'security')
        }
        Invoke-Stage 'sbom-inventory-and-vulnerability-gate' {
            & (Join-Path $PSScriptRoot 'Invoke-SbomScan.ps1') -Image $Image -EvidenceDirectory (Join-Path $evidence 'sbom-security')
        }
        if ($PublishImage) {
            Invoke-Stage 'publish-ghcr' {
                # DOCKER_CONFIG temporal evita cambiar la sesion del usuario y no se entrega como evidencia.
                $previousDockerConfig = [Environment]::GetEnvironmentVariable('DOCKER_CONFIG', 'Process')
                $previousDockerContext = [Environment]::GetEnvironmentVariable('DOCKER_CONTEXT', 'Process')
                $previousDockerHost = [Environment]::GetEnvironmentVariable('DOCKER_HOST', 'Process')
                $engineEndpoint = if ($previousDockerHost -and -not $previousDockerContext) { $previousDockerHost } else {
                    $endpoint = & docker context inspect --format '{{.Endpoints.docker.Host}}'
                    if ($LASTEXITCODE -ne 0 -or -not $endpoint) { throw 'No se pudo conservar el endpoint Docker seleccionado.' }
                    [string]$endpoint
                }
                $temporaryDockerConfig = Join-Path ([IO.Path]::GetTempPath()) ('devsu-ghcr-' + [Guid]::NewGuid().ToString('N'))
                New-Item -ItemType Directory -Path $temporaryDockerConfig | Out-Null
                try {
                    $env:DOCKER_CONFIG = $temporaryDockerConfig
                    # El config aislado no contiene los contextos de Docker Desktop del usuario.
                    [Environment]::SetEnvironmentVariable('DOCKER_CONTEXT', $null, 'Process')
                    $env:DOCKER_HOST = $engineEndpoint
                    $env:GHCR_TOKEN | & docker login ghcr.io --username $env:GHCR_USER --password-stdin
                    if ($LASTEXITCODE -ne 0) { throw 'Fallo la autenticacion GHCR.' }
                    & docker tag $Image $PublishImage
                    if ($LASTEXITCODE -ne 0) { throw 'Fallo el tag GHCR.' }
                    & docker push $PublishImage 2>&1 | Tee-Object -FilePath (Join-Path $evidence 'ghcr-push.log')
                    if ($LASTEXITCODE -ne 0) { throw 'Fallo la publicacion GHCR.' }
                    $digest = & docker image inspect --format '{{index .RepoDigests 0}}' $PublishImage
                    if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar el digest publicado.' }
                    @{ image = $PublishImage; digest = $digest } | ConvertTo-Json |
                        Set-Content -LiteralPath (Join-Path $evidence 'publication.json') -Encoding utf8
                } finally {
                    [Environment]::SetEnvironmentVariable('DOCKER_CONFIG', $previousDockerConfig, 'Process')
                    [Environment]::SetEnvironmentVariable('DOCKER_CONTEXT', $previousDockerContext, 'Process')
                    [Environment]::SetEnvironmentVariable('DOCKER_HOST', $previousDockerHost, 'Process')
                    # Solo se elimina el config temporal exacto creado por esta invocacion.
                    $resolvedTemporaryConfig = [IO.Path]::GetFullPath($temporaryDockerConfig)
                    $expectedTempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
                    if ([IO.Path]::GetDirectoryName($resolvedTemporaryConfig) -eq $expectedTempParent -and
                        [IO.Path]::GetFileName($resolvedTemporaryConfig) -like 'devsu-ghcr-*') {
                        Remove-Item -LiteralPath $resolvedTemporaryConfig -Recurse -Force
                    } else { throw 'La ruta temporal no coincide con el directorio creado para GHCR.' }
                }
            }
        }
    }
    if ($StopAfter -eq 'Kubernetes') {
        Invoke-Stage 'install-kubectl' {
            & (Join-Path $PSScriptRoot 'Install-Kubectl.ps1') -EvidenceDirectory (Join-Path $evidence 'kubectl-install')
        }
        Invoke-Stage 'install-kind' { & (Join-Path $project 'scripts/Install-Kind.ps1') }
        Invoke-Stage 'deploy-kubernetes' { & (Join-Path $project 'scripts/Deploy-Kubernetes.ps1') -Image $Image -LoadImage }
        Invoke-Stage 'validate-kubernetes' {
            & (Join-Path $project 'scripts/Test-Kubernetes.ps1') -EvidenceDirectory (Join-Path $evidence 'kubernetes')
        }
    }
    $passed = $true
} catch {
    $failure = $_.Exception.Message
    if ($env:GHCR_TOKEN) { $failure = $failure.Replace($env:GHCR_TOKEN, '[REDACTED]') }
} finally {
    Set-Location $previousLocation
    [ordered]@{
        startedAt = $started.ToString('o'); finishedAt = [DateTimeOffset]::UtcNow.ToString('o')
        source = 'local execution; not a GitHub Actions run'; requestedScope = $StopAfter
        passed = $passed; fullPipelineCompleted = $passed -and $StopAfter -eq 'Kubernetes'
        published = $passed -and -not [string]::IsNullOrWhiteSpace($PublishImage)
        publication = if ($PublishImage) { $PublishImage } else { 'not requested; no registry credentials used' }
        image = $Image; failure = $failure; stages = $stages.ToArray()
    } | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $evidence 'pipeline-summary.json') -Encoding utf8
}
if (-not $passed) { throw $failure }
Write-Output "Pipeline local terminado para alcance $StopAfter. Evidencia: $evidence"
