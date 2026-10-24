# Antes/despues de actualizar dependencias: solo consulta el cluster propio y PostgreSQL.
# Los snapshots contienen los usuarios sinteticos de la prueba, nunca credenciales.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Before', 'After')][string]$Mode,
    [string]$Kubeconfig = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.kube/devsu-kind.config'),
    [string]$EvidenceDirectory = (Join-Path $PSScriptRoot '../docs/evidence/security-remediation/postgres-upgrade'),
    [string]$BeforeSnapshotPath,
    [string]$ExpectedImage
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Se requiere PowerShell 7.' }
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$Kubeconfig = [IO.Path]::GetFullPath($Kubeconfig)
if (-not (Test-Path -LiteralPath "$Kubeconfig.ownership.json" -PathType Leaf)) { throw 'Falta la marca de propiedad del cluster.' }
$owner = Get-Content -LiteralPath "$Kubeconfig.ownership.json" -Raw | ConvertFrom-Json
if ($owner.cluster -ne 'devsu' -or $owner.managedBy -ne 'devsu-demo-deploy-script') { throw 'El kubeconfig no pertenece al procedimiento devsu.' }
$kubectl = (Get-Command kubectl -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$arguments = @('--kubeconfig', $Kubeconfig, '--context', 'kind-devsu', '-n', 'devsu')
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
$evidencePath = (Resolve-Path -LiteralPath $EvidenceDirectory).Path
if (-not $BeforeSnapshotPath) { $BeforeSnapshotPath = Join-Path $evidencePath 'before.json' }
$outputPath = Join-Path $evidencePath ($Mode.ToLowerInvariant() + '.json')
if (Test-Path -LiteralPath $outputPath) { throw "Ya existe $outputPath. Conserva ese resultado y utiliza otro EvidenceDirectory; After admite BeforeSnapshotPath." }
function Read-Kubernetes {
    param([string[]]$CommandArguments)
    $output = & $kubectl @arguments @CommandArguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw ('Consulta kubectl fallida: ' + (($output | ForEach-Object { $_.ToString() }) -join "`n")) }
    return (($output | ForEach-Object { $_.ToString() }) -join "`n").Trim()
}
$checks = [Collections.Generic.List[object]]::new()
function Check-Value {
    param([string]$Name, $Actual, $Expected)
    $ok = $Actual -ceq $Expected
    $checks.Add([ordered]@{ name = $Name; actual = $Actual; expected = $Expected; passed = $ok })
    if (-not $ok) { throw "No se conserva: $Name." }
}
$snapshot = [ordered]@{
    observedAt = [DateTimeOffset]::Now.ToString('o'); mode = $Mode; context = 'kind-devsu'; namespace = 'devsu'
    passed = $false; error = $null; readOnlySession = $null; users = @(); userCount = 0; flyway = @()
    pvcUID = $null; applicationImage = $null; applicationPods = @(); sourceMigrationV1SHA256 = $null
}
try {
    $namespace = Read-Kubernetes @('get', 'namespace', 'devsu', '-o', 'jsonpath={.metadata.labels.devsu-demo/managed-by}')
    Check-Value 'Namespace propio' $namespace 'deploy-script'
    $snapshot.pvcUID = Read-Kubernetes @('get', 'pvc', 'data-postgres-0', '-o', 'jsonpath={.metadata.uid}')
    $deployment = (Read-Kubernetes @('get', 'deployment', 'devsu-app', '-o', 'json')) | ConvertFrom-Json
    $snapshot.applicationImage = @($deployment.spec.template.spec.containers | Where-Object { $_.name -eq 'app' })[0].image
    $pods = (Read-Kubernetes @('get', 'pods', '-l', 'app=devsu-app', '-o', 'json')) | ConvertFrom-Json
    $snapshot.applicationPods = @($pods.items | Where-Object { -not $_.metadata.deletionTimestamp } | Sort-Object { $_.metadata.name } | ForEach-Object {
        [ordered]@{ name = $_.metadata.name; uid = $_.metadata.uid; image = $_.spec.containers[0].image; imageID = $_.status.containerStatuses[0].imageID }
    })
    Check-Value 'Imagen app identificada' (-not [string]::IsNullOrWhiteSpace($snapshot.applicationImage)) $true
    Check-Value 'Pods con imageID real disponible' ($snapshot.applicationPods.Count -gt 0 -and @($snapshot.applicationPods | Where-Object { -not $_.imageID }).Count -eq 0) $true
    if ($ExpectedImage) { Check-Value 'Imagen app esperada' $snapshot.applicationImage $ExpectedImage }
    $migration = Join-Path $root 'src/main/resources/db/migration/postgresql/V1__create_users.sql'
    $snapshot.sourceMigrationV1SHA256 = (Get-FileHash -LiteralPath $migration -Algorithm SHA256).Hash.ToLowerInvariant()
    # PGOPTIONS fuerza solo lectura; socket local del pod evita consultar el Secret.
    $sql = "SELECT json_build_object('readOnly', current_setting('transaction_read_only'), 'users', COALESCE((SELECT json_agg(u ORDER BY u.id) FROM (SELECT id,dni,name FROM users ORDER BY id) u), '[]'::json), 'flyway', COALESCE((SELECT json_agg(f ORDER BY f.installed_rank) FROM (SELECT installed_rank,version,checksum,success FROM flyway_schema_history ORDER BY installed_rank) f), '[]'::json));"
    $data = (Read-Kubernetes @('exec', 'postgres-0', '--', 'env', 'PGOPTIONS=-c default_transaction_read_only=on', 'psql', '-X', '-w', '-U', 'devsu', '-d', 'devsu', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', $sql)) | ConvertFrom-Json
    $snapshot.readOnlySession = $data.readOnly
    Check-Value 'Sesion PostgreSQL de solo lectura' $snapshot.readOnlySession 'on'
    $snapshot.users = @($data.users)
    $snapshot.userCount = $snapshot.users.Count
    $snapshot.flyway = @($data.flyway)
    if ($Mode -eq 'After') {
        $before = Get-Content -LiteralPath $BeforeSnapshotPath -Raw | ConvertFrom-Json
        Check-Value 'Snapshot Before aprobado' $before.passed $true
        Check-Value 'Modo del snapshot anterior' $before.mode 'Before'
        Check-Value 'Contexto original' $snapshot.context $before.context
        Check-Value 'PVC original' $snapshot.pvcUID $before.pvcUID
        Check-Value 'Archivo fuente V1 sin cambios' $snapshot.sourceMigrationV1SHA256 $before.sourceMigrationV1SHA256
        $beforeFlyway = ConvertTo-Json -InputObject @($before.flyway) -Compress -Depth 5
        $afterFlyway = ConvertTo-Json -InputObject @($snapshot.flyway) -Compress -Depth 5
        Check-Value 'Historial Flyway version/checksum/success identico' $afterFlyway $beforeFlyway
        $current = @{}
        foreach ($user in $snapshot.users) { $current[[string]$user.id] = $user }
        foreach ($user in @($before.users)) {
            Check-Value "Usuario previo ID $($user.id) existe" $current.ContainsKey([string]$user.id) $true
            Check-Value "Usuario previo ID $($user.id): DNI" $current[[string]$user.id].dni $user.dni
            Check-Value "Usuario previo ID $($user.id): nombre" $current[[string]$user.id].name $user.name
        }
        Check-Value 'Cantidad de usuarios no disminuye' ($snapshot.userCount -ge $before.userCount) $true
        $beforeIDs = @($before.applicationPods | ForEach-Object { $_.imageID } | Sort-Object -Unique) -join ','
        $afterIDs = @($snapshot.applicationPods | ForEach-Object { $_.imageID } | Sort-Object -Unique) -join ','
        Check-Value 'Cambio real de imageID tras actualizar' ($afterIDs -cne $beforeIDs) $true
        $snapshot['beforeSnapshotPath'] = [IO.Path]::GetFullPath($BeforeSnapshotPath)
        $snapshot['previousUserCount'] = $before.userCount
    }
    $snapshot.passed = $true
} catch { $snapshot.error = $_.Exception.Message }
finally {
    $snapshot['checks'] = $checks.ToArray()
    $snapshot | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $outputPath -Encoding utf8
}
if (-not $snapshot.passed) { throw "Snapshot $Mode fallido: $($snapshot.error). Revisa $outputPath." }
Write-Output "Snapshot $Mode aprobado: $($snapshot.userCount) usuarios; solo lectura. Evidencia: $outputPath"
