# Verificacion real sobre el cluster propio kind-devsu. Conserva los datos sinteticos.
# No borra el cluster ni PVC; elimina solo su Job de carga y sus port-forwards.
[CmdletBinding()]
param(
    [string]$Kubeconfig = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.kube/devsu-kind.config'),
    [string]$EvidenceDirectory = (Join-Path $PSScriptRoot '../target/kubernetes-evidence'),
    [ValidateRange(1024, 65535)][int]$IngressPort = 18080,
    [ValidateRange(1024, 65535)][int]$PodPortA = 18081,
    [ValidateRange(1024, 65535)][int]$PodPortB = 18082,
    [switch]$SkipLoad
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Se requiere PowerShell 7.' }
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$Kubeconfig = [IO.Path]::GetFullPath($Kubeconfig)
if (-not (Test-Path -LiteralPath "$Kubeconfig.ownership.json")) { throw 'No hay marca de propiedad del cluster propio.' }
$owner = Get-Content -LiteralPath "$Kubeconfig.ownership.json" -Raw | ConvertFrom-Json
if ($owner.cluster -ne 'devsu' -or $owner.managedBy -ne 'devsu-demo-deploy-script') { throw 'La marca de propiedad no corresponde a devsu.' }
if (@($IngressPort, $PodPortA, $PodPortB | Select-Object -Unique).Count -ne 3) { throw 'Los tres puertos deben ser distintos.' }
foreach ($port in @($IngressPort, $PodPortA, $PodPortB)) {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $port)
    try { $listener.Start() } catch { throw "Puerto $port ocupado." } finally { $listener.Stop() }
}
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
$evidencePath = (Resolve-Path -LiteralPath $EvidenceDirectory).Path
$kubectl = (Get-Command kubectl -CommandType Application -ErrorAction Stop).Source
$kubeArguments = @('--kubeconfig', $Kubeconfig, '--context', 'kind-devsu', '-n', 'devsu')
$checks = [Collections.Generic.List[object]]::new()
$commands = [Collections.Generic.List[object]]::new()
$httpResults = [Collections.Generic.List[object]]::new()
$history = [Collections.Generic.List[object]]::new()
$forwards = [Collections.Generic.List[object]]::new()
$startedAt = [DateTimeOffset]::Now.ToString('o')
$loadJob = 'devsu-http-load-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$loadCreated = $false
$passed = $false
$failure = $null
$cleanupErrors = [Collections.Generic.List[string]]::new()
$scaledUnderLoad = $false
$loadTotals = $null
function Assert-Value {
    param([string]$Name, $Actual, $Expected)
    $ok = $Actual -eq $Expected
    $checks.Add([ordered]@{ timestamp = [DateTimeOffset]::Now.ToString('o'); name = $Name; actual = $Actual; expected = $Expected; passed = $ok })
    if (-not $ok) { throw "Fallo: $Name." }
}
function Invoke-Kubectl {
    param([string[]]$Arguments, [string]$InputText, [string]$LogFile, [switch]$AllowFailure)
    $output = if ($InputText) { $InputText | & $kubectl @kubeArguments @Arguments 2>&1 } else { & $kubectl @kubeArguments @Arguments 2>&1 }
    $exitCode = $LASTEXITCODE
    $text = ($output | ForEach-Object { $_.ToString() }) -join "`n"
    $commands.Add([ordered]@{ timestamp = [DateTimeOffset]::Now.ToString('o'); arguments = $Arguments; exitCode = $exitCode; output = $text })
    if ($LogFile) { $text | Set-Content -LiteralPath (Join-Path $evidencePath $LogFile) -Encoding utf8 }
    if ($exitCode -ne 0 -and -not $AllowFailure) { throw "kubectl fallo ($exitCode); consulta kubernetes-results.json." }
    return $text.Trim()
}
function Get-AppPods {
    $pods = (Invoke-Kubectl @('get', 'pods', '-l', 'app=devsu-app', '-o', 'json')) | ConvertFrom-Json
    return @($pods.items | Where-Object { -not $_.metadata.deletionTimestamp })
}
function Get-ReadyPods {
    return @(Get-AppPods | Where-Object { @($_.status.conditions | Where-Object { $_.type -eq 'Ready' -and $_.status -eq 'True' }).Count -eq 1 })
}
function Wait-ReadyApps {
    param([int]$Minimum = 2, [int]$TimeoutSeconds = 240)
    $deadline = [DateTimeOffset]::Now.AddSeconds($TimeoutSeconds)
    do {
        $pods = @(Get-ReadyPods)
        if ($pods.Count -ge $Minimum) { return $pods }
        Start-Sleep -Seconds 3
    } while ([DateTimeOffset]::Now -lt $deadline)
    throw "No hay $Minimum pods Java Ready dentro del limite."
}
function Start-Forward {
    param([string]$Target, [int]$LocalPort, [int]$RemotePort, [string]$Label)
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $kubectl
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in ($kubeArguments + @('port-forward', '--address', '127.0.0.1', $Target, "${LocalPort}:$RemotePort"))) {
        $info.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $null = $process.Start()
    $record = @{ label = $Label; process = $process; stdout = $process.StandardOutput.ReadToEndAsync(); stderr = $process.StandardError.ReadToEndAsync() }
    $forwards.Add($record)
    $deadline = [DateTimeOffset]::Now.AddSeconds(30)
    do {
        if ($process.HasExited) { throw "El port-forward $Label termino antes de estar listo." }
        $client = [Net.Sockets.TcpClient]::new()
        try { $client.Connect('127.0.0.1', $LocalPort); return $record } catch { } finally { $client.Dispose() }
        Start-Sleep -Milliseconds 300
    } while ([DateTimeOffset]::Now -lt $deadline)
    throw "Port-forward $Label no disponible."
}
function Stop-Forward {
    param($Forward)
    if (-not $Forward.process.HasExited) { $Forward.process.Kill($true); $Forward.process.WaitForExit(10000) | Out-Null }
    $Forward.stdout.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $evidencePath "$($Forward.label).stdout.log") -Encoding utf8
    $Forward.stderr.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $evidencePath "$($Forward.label).stderr.log") -Encoding utf8
}
function Invoke-Api {
    param([int]$Port, [string]$Path, [int]$ExpectedStatus = 200, [string]$Method = 'Get', [string]$Body, [switch]$Ingress)
    $url = "http://127.0.0.1:$Port/api$Path"
    $headers = @{ Accept = 'application/json' }
    if ($Ingress) { $headers.Host = 'devsu.local' }
    $parameters = @{ Uri = $url; Method = $Method; Headers = $headers; TimeoutSec = 15; SkipHttpErrorCheck = $true }
    if ($Body) { $parameters.Body = $Body; $parameters.ContentType = 'application/json' }
    $response = Invoke-WebRequest @parameters
    $content = [string]$response.Content
    $httpResults.Add([ordered]@{ timestamp = [DateTimeOffset]::Now.ToString('o'); url = $url; ingressHost = $(if ($Ingress) { 'devsu.local' } else { $null }); method = $Method; actualStatus = [int]$response.StatusCode; expectedStatus = $ExpectedStatus; requestBody = $Body; responseBody = $content })
    Assert-Value "$Method $url$(if ($Ingress) { ' via Ingress' })" ([int]$response.StatusCode) $ExpectedStatus
    if ($content) { return $content | ConvertFrom-Json }
}
function Wait-HpaBaseline {
    $deadline = [DateTimeOffset]::Now.AddSeconds(240)
    do {
        $hpa = (Invoke-Kubectl @('get', 'hpa', 'devsu-app', '-o', 'json')) | ConvertFrom-Json
        $ready = @(Get-ReadyPods).Count
        $history.Add([ordered]@{ timestamp = [DateTimeOffset]::Now.ToString('o'); phase = 'idle-baseline'; currentReplicas = $hpa.status.currentReplicas; desiredReplicas = $hpa.status.desiredReplicas; readyReplicas = $ready; currentMetrics = $hpa.status.currentMetrics; conditions = $hpa.status.conditions })
        if ($hpa.status.currentReplicas -eq 2 -and $hpa.status.desiredReplicas -eq 2 -and $ready -eq 2 -and
            @($hpa.status.conditions | Where-Object { $_.type -eq 'ScalingActive' -and $_.status -eq 'True' }).Count -eq 1) { return }
        Start-Sleep -Seconds 5
    } while ([DateTimeOffset]::Now -lt $deadline)
    throw 'HPA no alcanzo una linea base estable de dos replicas con metricas disponibles.'
}
try {
    $label = Invoke-Kubectl @('get', 'namespace', 'devsu', '-o', 'jsonpath={.metadata.labels.devsu-demo/managed-by}')
    Assert-Value 'Namespace propio' $label 'deploy-script'
    $null = Invoke-Kubectl @('get', 'nodes', '-o', 'wide') -LogFile 'nodes.log'
    $null = Invoke-Kubectl @('get', 'deployment', 'devsu-app', '-o', 'json') -LogFile 'app-deployment.json'
    $hpaConfig = (Invoke-Kubectl @('get', 'hpa', 'devsu-app', '-o', 'json')) | ConvertFrom-Json
    Assert-Value 'HPA minimo dos replicas' $hpaConfig.spec.minReplicas 2
    Assert-Value 'HPA maximo cuatro replicas' $hpaConfig.spec.maxReplicas 4
    $pods = @(Wait-ReadyApps)
    Assert-Value 'Al menos dos pods Ready' ($pods.Count -ge 2) $true
    Assert-Value 'UID efectivo pod Java' (Invoke-Kubectl @('exec', $pods[0].metadata.name, '--', 'id', '-u')) '10001'
    $null = Invoke-Kubectl @('exec', $pods[0].metadata.name, '--', 'test', '-w', '/tmp')
    $pvc = (Invoke-Kubectl @('get', 'pvc', 'data-postgres-0', '-o', 'json')) | ConvertFrom-Json
    Assert-Value 'PVC PostgreSQL enlazado' $pvc.status.phase 'Bound'
    $pvcUid = $pvc.metadata.uid
    $forwardIngress = Start-Forward 'service/traefik' $IngressPort 80 'ingress-forward'
    $forwardA = Start-Forward "pod/$($pods[0].metadata.name)" $PodPortA 8000 'pod-a-forward'
    $forwardB = Start-Forward "pod/$($pods[1].metadata.name)" $PodPortB 8000 'pod-b-forward'
    $ready = Invoke-Api $IngressPort '/actuator/health/readiness' -Ingress
    Assert-Value 'Readiness por Ingress' $ready.status 'UP'
    $dni = [string][Security.Cryptography.RandomNumberGenerator]::GetInt32(1000000000, 2147483647)
    $created = Invoke-Api -Port $PodPortA -Path '/users' -ExpectedStatus 201 -Method Post -Body (@{ dni = $dni; name = 'Kubernetes Prueba' } | ConvertTo-Json -Compress)
    $readFromB = Invoke-Api $PodPortB "/users/$($created.id)"
    foreach ($field in @('id', 'dni', 'name')) { Assert-Value "Pod B lee campo $field creado en A" $readFromB.$field $created.$field }
    $ingressUser = Invoke-Api $IngressPort "/users/$($created.id)" -Ingress
    foreach ($field in @('id', 'dni', 'name')) { Assert-Value "Ingress devuelve $field" $ingressUser.$field $created.$field }
    Stop-Forward $forwardA
    $replacedPodUid = $pods[0].metadata.uid
    $null = Invoke-Kubectl @('delete', 'pod', $pods[0].metadata.name, '--wait=true', '--timeout=60s') -LogFile 'app-pod-delete.log'
    $newPods = @(Wait-ReadyApps)
    Assert-Value 'Pod Java reemplazado por controlador' (@($newPods | Where-Object { $_.metadata.uid -eq $replacedPodUid }).Count -eq 0) $true
    $afterApp = Invoke-Api $IngressPort "/users/$($created.id)" -Ingress
    Assert-Value 'Datos tras reemplazar pod Java' $afterApp.dni $created.dni
    $postgresBefore = (Invoke-Kubectl @('get', 'pod', 'postgres-0', '-o', 'json')) | ConvertFrom-Json
    $null = Invoke-Kubectl @('delete', 'pod', 'postgres-0', '--wait=true', '--timeout=60s') -LogFile 'postgres-pod-delete.log'
    $deadline = [DateTimeOffset]::Now.AddSeconds(240)
    do {
        $pgText = Invoke-Kubectl @('get', 'pod', 'postgres-0', '--ignore-not-found', '-o', 'json')
        if ($pgText) {
            $postgresAfter = $pgText | ConvertFrom-Json
            if ($postgresAfter.metadata.uid -ne $postgresBefore.metadata.uid -and @($postgresAfter.status.conditions | Where-Object { $_.type -eq 'Ready' -and $_.status -eq 'True' }).Count -eq 1) { break }
        }
        Start-Sleep -Seconds 2
    } while ([DateTimeOffset]::Now -lt $deadline)
    Assert-Value 'Pod PostgreSQL reemplazado y Ready' ($postgresAfter.metadata.uid -ne $postgresBefore.metadata.uid -and @($postgresAfter.status.conditions | Where-Object { $_.type -eq 'Ready' -and $_.status -eq 'True' }).Count -eq 1) $true
    $pvcAfter = (Invoke-Kubectl @('get', 'pvc', 'data-postgres-0', '-o', 'json')) | ConvertFrom-Json
    Assert-Value 'Mismo PVC tras reiniciar PostgreSQL' $pvcAfter.metadata.uid $pvcUid
    $null = Wait-ReadyApps
    # Dar tiempo al controlador Ingress para observar los endpoints recuperados.
    Start-Sleep -Seconds 3
    $afterPg = Invoke-Api $IngressPort "/users/$($created.id)" -Ingress
    foreach ($field in @('id', 'dni', 'name')) { Assert-Value "Persistencia tras reiniciar PostgreSQL: $field" $afterPg.$field $created.$field }
    if (-not $SkipLoad) {
        Stop-Forward $forwardB
        Wait-HpaBaseline
        $loadManifest = (Get-Content -LiteralPath (Join-Path $root 'k8s/load-job.yaml') -Raw).Replace('name: devsu-http-load', "name: $loadJob")
        $null = Invoke-Kubectl -Arguments @('create', '-f', '-') -InputText $loadManifest
        $loadCreated = $true
        $null = Invoke-Kubectl @('wait', '--for=condition=Ready', 'pod', '-l', "job-name=$loadJob", '--timeout=90s')
        $deadline = [DateTimeOffset]::Now.AddSeconds(270)
        do {
            $hpa = (Invoke-Kubectl @('get', 'hpa', 'devsu-app', '-o', 'json')) | ConvertFrom-Json
            $readyCount = @(Get-ReadyPods).Count
            $history.Add([ordered]@{ timestamp = [DateTimeOffset]::Now.ToString('o'); phase = 'real-http-load'; currentReplicas = $hpa.status.currentReplicas; desiredReplicas = $hpa.status.desiredReplicas; readyReplicas = $readyCount; currentMetrics = $hpa.status.currentMetrics; conditions = $hpa.status.conditions })
            if ($hpa.status.desiredReplicas -gt 2 -and $readyCount -gt 2) { $scaledUnderLoad = $true; break }
            Start-Sleep -Seconds 5
        } while ([DateTimeOffset]::Now -lt $deadline)
        $loadPods = (Invoke-Kubectl @('get', 'pods', '-l', "job-name=$loadJob", '-o', 'json')) | ConvertFrom-Json
        if ($loadPods.items.Count -eq 1 -and $loadPods.items[0].status.phase -eq 'Running') {
            $null = Invoke-Kubectl @('exec', $loadPods.items[0].metadata.name, '--', 'touch', '/tmp/stop')
        }
        $workerDeadline = [DateTimeOffset]::Now.AddSeconds(15)
        do {
            $loadLogs = Invoke-Kubectl @('logs', "job/$loadJob") -LogFile 'http-load.log'
            $workerReports = @($loadLogs -split '\r?\n' | Where-Object { $_ -match 'worker=\d+ success=\d+ failure=\d+' }).Count
            if ($workerReports -eq 16) { break }
            Start-Sleep -Seconds 1
        } while ([DateTimeOffset]::Now -lt $workerDeadline)
        Assert-Value 'Dieciseis trabajadores HTTP informaron resultados' $workerReports 16
        $successes = 0L; $errors = 0L
        foreach ($line in ($loadLogs -split '\r?\n')) {
            if ($line -match 'worker=\d+ success=(\d+) failure=(\d+)') { $successes += [long]$Matches[1]; $errors += [long]$Matches[2] }
        }
        $loadTotals = @{ successfulRequests = $successes; failedRequests = $errors }
        Assert-Value 'Carga produjo peticiones HTTP exitosas' ($successes -gt 0) $true
        Assert-Value 'HPA aumento y preparo replicas durante carga HTTP real' $scaledUnderLoad $true
        $null = Invoke-Kubectl @('top', 'pods') -LogFile 'pod-metrics.log'
        $null = Invoke-Kubectl @('describe', 'hpa', 'devsu-app') -LogFile 'hpa-describe.log'
    }
    $null = Invoke-Kubectl @('get', 'pods,deployments,statefulsets,services,pvc,hpa,ingresses', '-o', 'wide') -LogFile 'resources-final.log'
    $passed = $true
} catch {
    $failure = $_.Exception.Message
} finally {
    foreach ($forward in $forwards) {
        try { Stop-Forward $forward } catch { $cleanupErrors.Add("Port-forward: $($_.Exception.Message)") }
    }
    if ($loadCreated) {
        try { $null = Invoke-Kubectl @('delete', 'job', $loadJob, '--ignore-not-found', '--wait=true', '--timeout=60s') -LogFile 'load-job-cleanup.log' }
        catch { $cleanupErrors.Add("Job: $($_.Exception.Message)") }
    }
    try { $null = Invoke-Kubectl @('get', 'events', '--sort-by=.lastTimestamp') -LogFile 'events.log' } catch { }
    [ordered]@{
        startedAt = $startedAt; finishedAt = [DateTimeOffset]::Now.ToString('o'); context = 'kind-devsu'; namespace = 'devsu'
        passed = ($passed -and $cleanupErrors.Count -eq 0); error = $failure; cleanupErrors = $cleanupErrors.ToArray()
        publicEndpoint = $false; loadSkipped = [bool]$SkipLoad; scaledUnderRealHttpLoad = $scaledUnderLoad
        loadTotals = $loadTotals; checks = $checks.ToArray(); http = $httpResults.ToArray(); commands = $commands.ToArray()
    } | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $evidencePath 'kubernetes-results.json') -Encoding utf8
    $history.ToArray() | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $evidencePath 'hpa-history.json') -Encoding utf8
}
if (-not $passed -or $cleanupErrors.Count -gt 0) { throw "Verificacion Kubernetes incompleta: $failure. Evidencia: $evidencePath" }
Write-Output "Kubernetes verificado: $($checks.Count) comprobaciones; escalamiento HTTP observado=$scaledUnderLoad. Sin endpoint publico."
