# Despliega exclusivamente en el cluster kind devsu, con kubeconfig privado fuera del repo.
[CmdletBinding()]
param(
    [string]$Image = 'devsu-demo-java:local',
    [switch]$LoadImage,
    [switch]$InfrastructureOnly,
    [switch]$AllowLowMemory,
    [string]$Kubeconfig = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.kube/devsu-kind.config'),
    [string]$EvidenceDirectory = (Join-Path $PSScriptRoot '../target/kubernetes-deploy-evidence')
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Se requiere PowerShell 7.' }
if ($Image -notmatch '^[a-zA-Z0-9][a-zA-Z0-9./:@_-]+$') { throw 'Referencia de imagen no valida.' }
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$Kubeconfig = [IO.Path]::GetFullPath($Kubeconfig)
if ($Kubeconfig.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Kubeconfig contiene credenciales y debe estar fuera del repositorio.'
}
$ownerFile = "$Kubeconfig.ownership.json"
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
$evidencePath = (Resolve-Path -LiteralPath $EvidenceDirectory).Path
$commands = [System.Collections.Generic.List[object]]::new()
$startedAt = [DateTimeOffset]::Now.ToString('o')
$password = ''
$encodedPassword = ''
$passed = $false
$failure = $null
$createdCluster = $false
$nodeImage = 'kindest/node:v1.36.4@sha256:099e049362a1526b2db71494e1947aae99bd16290d7c895f2b7ea312e3cbfaed'
$busyboxImage = 'busybox:1.37.0-musl@sha256:5cec3fc171c87218698e85a52af7087de727372aae264a787b8112901a5b0092'
$kubeArguments = @('--kubeconfig', $Kubeconfig, '--context', 'kind-devsu')
function Protect-Output {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return $null }
    foreach ($value in @($password, $encodedPassword)) {
        if ($value) { $Text = $Text.Replace($value, '[REDACTED]') }
    }
    return $Text
}
function Invoke-Tool {
    param([string]$Tool, [string[]]$Arguments, [string]$InputText, [string]$LogFile)
    $output = if ($InputText) { $InputText | & $Tool @Arguments 2>&1 } else { & $Tool @Arguments 2>&1 }
    $exitCode = $LASTEXITCODE
    $safe = Protect-Output (($output | ForEach-Object { $_.ToString() }) -join "`n")
    $commands.Add([ordered]@{ timestamp = [DateTimeOffset]::Now.ToString('o'); tool = $Tool; arguments = $Arguments; exitCode = $exitCode; output = $safe })
    if ($LogFile) { $safe | Set-Content -LiteralPath (Join-Path $evidencePath $LogFile) -Encoding utf8 }
    if ($exitCode -ne 0) { throw "$Tool fallo con codigo $exitCode; consulta deploy-results.json." }
    return $safe.Trim()
}
function Invoke-Kubectl {
    param([string[]]$Arguments, [string]$InputText, [string]$LogFile)
    return Invoke-Tool -Tool 'kubectl' -Arguments ($kubeArguments + $Arguments) -InputText $InputText -LogFile $LogFile
}
try {
    $null = Get-Command docker -CommandType Application -ErrorAction Stop
    $null = Get-Command kubectl -CommandType Application -ErrorAction Stop
    $engine = Invoke-Tool 'docker' @('info', '--format', '{{.OSType}}')
    if ($engine -ne 'linux') { throw 'Se requiere Docker Linux operativo.' }
    $freeMiB = $null
    if ($IsWindows) {
        $freeMiB = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)
        if ($freeMiB -lt 3072 -and -not $AllowLowMemory) {
            throw "Solo hay $freeMiB MiB libres. Cierra herramientas innecesarias o utiliza CI. -AllowLowMemory permite un intento consciente con limites de Docker; puede paginar."
        }
    }
    [ordered]@{ checkedAt = [DateTimeOffset]::Now.ToString('o'); freeHostMiB = $freeMiB; allowLowMemory = [bool]$AllowLowMemory } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidencePath 'memory-preflight.json') -Encoding utf8
    $kindPath = Join-Path ([Environment]::GetFolderPath('UserProfile')) ('.cache/devsu-demo-tools/kind/v0.33.0/' + $(if ($IsWindows) { 'kind.exe' } else { 'kind' }))
    if (-not (Test-Path -LiteralPath $kindPath -PathType Leaf)) {
        $null = & (Join-Path $PSScriptRoot 'Install-Kind.ps1') -EvidenceDirectory (Join-Path $evidencePath 'kind-install')
    }
    $kindVersion = Invoke-Tool $kindPath @('version')
    if ($kindVersion -notmatch '^kind v0\.33\.0 ') { throw 'La version de kind no coincide con v0.33.0.' }
    $clusters = Invoke-Tool $kindPath @('get', 'clusters')
    $exists = @($clusters -split '\r?\n') -contains 'devsu'
    $owner = if (Test-Path -LiteralPath $ownerFile -PathType Leaf) { Get-Content -LiteralPath $ownerFile -Raw | ConvertFrom-Json } else { $null }
    if ($exists) {
        if (-not $owner -or $owner.cluster -ne 'devsu' -or $owner.managedBy -ne 'devsu-demo-deploy-script' -or -not (Test-Path -LiteralPath $Kubeconfig)) {
            throw 'Ya existe un cluster devsu sin la marca de propiedad de este procedimiento. No se modificara.'
        }
    } else {
        if ((Test-Path -LiteralPath $Kubeconfig) -and -not $owner) { throw 'El kubeconfig elegido ya existe y no pertenece a este procedimiento.' }
        New-Item -ItemType Directory -Path (Split-Path -Parent $Kubeconfig) -Force | Out-Null
        $null = Invoke-Tool $kindPath @('create', 'cluster', '--name', 'devsu', '--image', $nodeImage, '--config', (Join-Path $root 'k8s/kind.yaml'), '--kubeconfig', $Kubeconfig, '--wait', '180s') -LogFile 'kind-create.log'
        $createdCluster = $true
        [ordered]@{ cluster = 'devsu'; context = 'kind-devsu'; managedBy = 'devsu-demo-deploy-script'; createdAt = [DateTimeOffset]::Now.ToString('o'); nodeImage = $nodeImage } |
            ConvertTo-Json | Set-Content -LiteralPath $ownerFile -Encoding utf8
    }
    $nodes = Invoke-Tool $kindPath @('get', 'nodes', '--name', 'devsu')
    if ($nodes -ne 'devsu-control-plane') { throw 'Se esperaba exclusivamente un nodo propio devsu-control-plane.' }
    $nodeOwner = Invoke-Tool 'docker' @('inspect', '--format', '{{index .Config.Labels "io.x-k8s.kind.cluster"}}', 'devsu-control-plane')
    if ($nodeOwner -ne 'devsu') { throw 'El nodo Docker no pertenece al cluster devsu.' }
    $nodeCpus = [math]::Min(4, [Environment]::ProcessorCount)
    $null = Invoke-Tool 'docker' @('update', '--memory', '4g', '--memory-swap', '4g', '--cpus', [string]$nodeCpus, 'devsu-control-plane') -LogFile 'node-resource-limits.log'
    $null = Invoke-Kubectl @('wait', '--for=condition=Ready', 'node/devsu-control-plane', '--timeout=180s')
    $null = Invoke-Kubectl @('version', '-o', 'json') -LogFile 'kubernetes-version.json'
    $namespaceText = Invoke-Kubectl @('get', 'namespace', 'devsu', '--ignore-not-found', '-o', 'json')
    if ($namespaceText) {
        $namespaceOwner = ($namespaceText | ConvertFrom-Json).metadata.labels.'devsu-demo/managed-by'
        if ($namespaceOwner -ne 'deploy-script') { throw 'El namespace devsu existente no pertenece a este procedimiento; no se modificara.' }
    }
    $null = Invoke-Kubectl @('apply', '-f', (Join-Path $root 'k8s/namespace.yaml'))
    # El helper de volumen usa tambien una imagen fijada, sin dejar busybox:latest implicito.
    $localPath = (Invoke-Kubectl @('-n', 'local-path-storage', 'get', 'configmap', 'local-path-config', '-o', 'json')) | ConvertFrom-Json
    if ($localPath.data.'helperPod.yaml') {
        $localPath.data.'helperPod.yaml' = $localPath.data.'helperPod.yaml' -replace '(?m)^(\s*image:\s*).+$', ('$1' + $busyboxImage)
        $localPath.metadata.PSObject.Properties.Remove('managedFields')
        $null = Invoke-Kubectl -Arguments @('apply', '-f', '-') -InputText ($localPath | ConvertTo-Json -Depth 20)
    }
    $null = Invoke-Kubectl @('apply', '-f', (Join-Path $root 'k8s/metrics-server.yaml'))
    $null = Invoke-Kubectl @('apply', '-f', (Join-Path $root 'k8s/traefik.yaml'))
    $null = Invoke-Kubectl @('-n', 'kube-system', 'rollout', 'status', 'deployment/metrics-server', '--timeout=180s') -LogFile 'metrics-rollout.log'
    $null = Invoke-Kubectl @('-n', 'devsu', 'rollout', 'status', 'deployment/traefik', '--timeout=180s') -LogFile 'traefik-rollout.log'
    if (-not $InfrastructureOnly) {
        if ($LoadImage) {
            $null = Invoke-Tool 'docker' @('image', 'inspect', '--format', '{{.Id}}', $Image) -LogFile 'application-image-id.log'
            $null = Invoke-Tool $kindPath @('load', 'docker-image', '--name', 'devsu', $Image) -LogFile 'kind-load-image.log'
        }
        $secretName = Invoke-Kubectl @('-n', 'devsu', 'get', 'secret', 'devsu-db', '--ignore-not-found', '-o', 'name')
        if (-not $secretName) {
            $password = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
            $encodedPassword = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($password))
            $secret = @{ apiVersion = 'v1'; kind = 'Secret'; metadata = @{ name = 'devsu-db'; namespace = 'devsu' }; type = 'Opaque'; data = @{ password = $encodedPassword } }
            $null = Invoke-Kubectl -Arguments @('create', '-f', '-') -InputText ($secret | ConvertTo-Json -Depth 5 -Compress)
            $password = ''; $encodedPassword = ''
        }
        $null = Invoke-Kubectl @('apply', '-f', (Join-Path $root 'k8s/configmap.yaml'))
        $null = Invoke-Kubectl @('apply', '-f', (Join-Path $root 'k8s/postgres.yaml'))
        $null = Invoke-Kubectl @('-n', 'devsu', 'rollout', 'status', 'statefulset/postgres', '--timeout=240s') -LogFile 'postgres-rollout.log'
        # Sustituir antes de aplicar evita crear primero pods con una etiqueta incorrecta.
        $appManifest = Get-Content -LiteralPath (Join-Path $root 'k8s/app.yaml') -Raw
        $appManifest = $appManifest.Replace('image: devsu-demo-java:local', "image: $Image")
        $configHash = (Get-FileHash -LiteralPath (Join-Path $root 'k8s/configmap.yaml') -Algorithm SHA256).Hash.ToLowerInvariant()
        $appManifest = $appManifest.Replace('checksum/config: pending', "checksum/config: $configHash")
        $null = Invoke-Kubectl -Arguments @('apply', '-f', '-') -InputText $appManifest
        $null = Invoke-Kubectl @('apply', '-f', (Join-Path $root 'k8s/hpa.yaml'))
        $null = Invoke-Kubectl @('apply', '-f', (Join-Path $root 'k8s/ingress.yaml'))
        $null = Invoke-Kubectl @('-n', 'devsu', 'rollout', 'status', 'deployment/devsu-app', '--timeout=360s') -LogFile 'app-rollout.log'
        $null = Invoke-Kubectl @('-n', 'devsu', 'get', 'pods,deployments,statefulsets,services,pvc,hpa,ingresses', '-o', 'wide') -LogFile 'resources.log'
    }
    $passed = $true
} catch {
    $failure = Protect-Output $_.Exception.Message
} finally {
    [ordered]@{
        startedAt = $startedAt; finishedAt = [DateTimeOffset]::Now.ToString('o'); passed = $passed
        cluster = 'devsu'; context = 'kind-devsu'; nodeImage = $nodeImage; image = $Image
        infrastructureOnly = [bool]$InfrastructureOnly; createdCluster = $createdCluster
        publicEndpoint = $false; error = $failure; commands = $commands.ToArray()
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidencePath 'deploy-results.json') -Encoding utf8
}
if (-not $passed) { throw "Despliegue incompleto: $failure. Evidencia: $evidencePath" }
Write-Output "Despliegue verificado en kind-devsu; namespace devsu. Sin endpoint publico. Evidencia: $evidencePath"
