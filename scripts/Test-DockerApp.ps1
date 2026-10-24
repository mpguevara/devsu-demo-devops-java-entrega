# Prueba aislada de una imagen ya construida. Requiere PowerShell 7 y Docker Linux.
# Crea una base efimera propia y elimina exclusivamente su proyecto Compose al terminar.
[CmdletBinding()]
param(
    [ValidateSet('devsu-demo-java:local')][string]$Image = 'devsu-demo-java:local',
    [string]$EvidenceDirectory = (Join-Path $PSScriptRoot '..\target\docker-app-evidence'),
    [ValidateRange(1024, 65535)][int]$AppPort = 8003,
    [ValidateRange(1024, 65535)][int]$PostgresPort = 55434,
    [ValidateRange(1024, 65535)][int]$ContainerPort = 8080
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Este script requiere PowerShell 7.' }
if ($AppPort -eq $PostgresPort) { throw 'AppPort y PostgresPort deben ser distintos.' }
$null = Get-Command docker -CommandType Application -ErrorAction Stop
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$composeFiles = @((Join-Path $projectPath 'compose.yaml'), (Join-Path $projectPath 'compose.app.yaml'))
foreach ($file in $composeFiles) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "No existe $file." }
}
$healthScript = Join-Path $PSScriptRoot 'Test-HealthApi.ps1'
if (-not (Test-Path -LiteralPath $healthScript -PathType Leaf)) { throw 'Falta Test-HealthApi.ps1.' }
foreach ($port in @($AppPort, $PostgresPort)) {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)
    try { $listener.Start() } catch { throw "El puerto local $port no esta disponible." }
    finally { $listener.Stop() }
}
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
$evidencePath = (Resolve-Path -LiteralPath $EvidenceDirectory).Path
$project = 'devsu-verify-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$compose = @('compose', '--project-directory', $projectPath, '-p', $project,
    '-f', $composeFiles[0], '-f', $composeFiles[1])
$baseUrl = "http://127.0.0.1:$AppPort/api"
$startedAt = [DateTimeOffset]::Now.ToString('o')
$checks = [System.Collections.Generic.List[object]]::new()
$commands = [System.Collections.Generic.List[object]]::new()
$snapshots = [System.Collections.Generic.List[object]]::new()
$failures = [System.Collections.Generic.List[string]]::new()
$previousEnvironment = @{}
foreach ($key in @('PASSWORD_DB', 'APP_PORT', 'POSTGRES_PORT', 'PORT')) {
    $previousEnvironment[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
}
$password = [Convert]::ToHexString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
$appId = $null
$postgresId = $null
$cleanupRequired = $false
$cleanupSucceeded = $false
$workflowCompleted = $false
$jarHashes = $null

function Protect-Text {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return $null }
    return $Text.Replace($password, '[REDACTED]')
}

function Assert-Value {
    param([string]$Name, $Actual, $Expected)
    $ok = $Actual -eq $Expected
    $checks.Add([ordered]@{
        timestamp = [DateTimeOffset]::Now.ToString('o'); name = $Name
        actual = $Actual; expected = $Expected; passed = $ok
    })
    if (-not $ok) { throw "Fallo la comprobacion: $Name." }
}

function Invoke-Docker {
    param([string[]]$Arguments, [string]$LogFile)
    $output = & docker @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $safeOutput = Protect-Text (($output | ForEach-Object { $_.ToString() }) -join "`n")
    if ($LogFile) {
        $safeOutput | Set-Content -LiteralPath (Join-Path $evidencePath $LogFile) -Encoding utf8
    }
    $commands.Add([ordered]@{
        timestamp = [DateTimeOffset]::Now.ToString('o'); arguments = $Arguments
        exitCode = $exitCode; logFile = $LogFile
        errorOutput = if ($exitCode -ne 0) { $safeOutput } else { $null }
    })
    if ($exitCode -ne 0) { throw "Docker fallo con codigo $exitCode. Revisa $LogFile y docker-results.json." }
    return $safeOutput.Trim()
}

function Get-OwnContainer {
    param([string]$Id, [string]$Service, [string]$Phase)
    # Seleccion explicita: nunca guardar Config.Env ni el inspect completo.
    $format = '{"id":{{json .Id}},"name":{{json .Name}},"project":{{json (index .Config.Labels "com.docker.compose.project")}},"service":{{json (index .Config.Labels "com.docker.compose.service")}},"image":{{json .Config.Image}},"user":{{json .Config.User}},"readonlyRootfs":{{json .HostConfig.ReadonlyRootfs}},"capDrop":{{json .HostConfig.CapDrop}},"securityOpt":{{json .HostConfig.SecurityOpt}},"tmpfs":{{json (index .HostConfig "Tmpfs")}},"mounts":{{json .Mounts}},"oomKilled":{{json .State.OOMKilled}},"restartCount":{{json .RestartCount}},"running":{{json .State.Running}},"exitCode":{{json .State.ExitCode}},"healthStatus":{{if .State.Health}}{{json .State.Health.Status}}{{else}}"none"{{end}}}'
    $metadata = (Invoke-Docker -Arguments @('inspect', '--format', $format, $Id)) | ConvertFrom-Json
    if ($metadata.project -cne $project -or $metadata.service -cne $Service -or
        $metadata.name -notmatch ('^/' + [regex]::Escape($project) + '[-_]')) {
        throw 'El contenedor no pertenece al proyecto de verificacion; no se modificara.'
    }
    $snapshots.Add([ordered]@{ phase = $Phase; metadata = $metadata })
    return $metadata
}

function Invoke-HealthPhase {
    param([string]$Phase, [string]$Expected)
    $phaseDirectory = Join-Path $evidencePath $Phase
    $output = & $healthScript -BaseUrl $baseUrl -ExpectedReadiness $Expected -EvidenceDirectory $phaseDirectory
    (Protect-Text ($output -join "`n")) | Set-Content -LiteralPath (Join-Path $phaseDirectory 'execution.log') -Encoding utf8
    $result = Get-Content -LiteralPath (Join-Path $phaseDirectory 'http-results.json') -Raw | ConvertFrom-Json
    Assert-Value "$Phase salud HTTP" $result.passed $true
}

function Wait-Readiness {
    param([string]$Expected, [int]$TimeoutSeconds = 60)
    $deadline = [DateTimeOffset]::Now.AddSeconds($TimeoutSeconds)
    $actualStatus = $null
    $actualHealth = $null
    do {
        try {
            $response = Invoke-WebRequest -Uri "$baseUrl/actuator/health/readiness" -Headers @{ Accept = 'application/json' } -TimeoutSec 5 -SkipHttpErrorCheck
            $actualStatus = [int]$response.StatusCode
            $actualHealth = ($response.Content | ConvertFrom-Json).status
            $expectedStatus = if ($Expected -eq 'UP') { 200 } else { 503 }
            if ($actualStatus -eq $expectedStatus -and $actualHealth -eq $Expected) {
                Assert-Value "Readiness alcanza $Expected" $actualHealth $Expected
                return
            }
        } catch { }
        Start-Sleep -Milliseconds 500
    } while ([DateTimeOffset]::Now -lt $deadline)
    Assert-Value "Readiness alcanza $Expected" "$actualStatus/$actualHealth" $Expected
}

function Invoke-UserRequest {
    param([string]$Method, [string]$Path, [int]$ExpectedStatus, [string]$Body, [string]$Phase)
    $parameters = @{
        Uri = "$baseUrl$Path"; Method = $Method; TimeoutSec = 10
        SkipHttpErrorCheck = $true; Headers = @{ Accept = 'application/json' }
    }
    if ($Body) { $parameters.Body = $Body; $parameters.ContentType = 'application/json' }
    $response = Invoke-WebRequest @parameters
    [ordered]@{
        timestamp = [DateTimeOffset]::Now.ToString('o'); method = $Method; url = "$baseUrl$Path"
        requestBody = $Body; actualStatus = [int]$response.StatusCode; expectedStatus = $ExpectedStatus
        responseBody = Protect-Text ([string]$response.Content)
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidencePath "$Phase-user.json") -Encoding utf8
    Assert-Value "$Phase HTTP $Method" ([int]$response.StatusCode) $ExpectedStatus
    return $response.Content | ConvertFrom-Json
}

try {
    $env:PASSWORD_DB = $password
    $env:APP_PORT = [string]$AppPort
    $env:POSTGRES_PORT = [string]$PostgresPort
    $env:PORT = [string]$ContainerPort
    $engine = Invoke-Docker -Arguments @('info', '--format', '{{.OSType}}') -LogFile 'docker-engine.log'
    Assert-Value 'Motor Docker Linux' $engine 'linux'
    $null = Invoke-Docker -Arguments @('image', 'inspect', '--format', '{{.Id}}', $Image) -LogFile 'image-id.log'
    $existingContainers = Invoke-Docker -Arguments @('ps', '-aq', '--filter', "label=com.docker.compose.project=$project")
    $existingVolumes = Invoke-Docker -Arguments @('volume', 'ls', '-q', '--filter', "label=com.docker.compose.project=$project")
    Assert-Value 'Proyecto no contiene contenedores preexistentes' $existingContainers ''
    Assert-Value 'Proyecto no contiene volumenes preexistentes' $existingVolumes ''
    $cleanupRequired = $true
    $null = Invoke-Docker -Arguments ($compose + @('up', '-d', '--no-build', '--wait', '--wait-timeout', '180')) -LogFile 'compose-up.log'
    $appId = Invoke-Docker -Arguments ($compose + @('ps', '-q', 'app'))
    $postgresId = Invoke-Docker -Arguments ($compose + @('ps', '-q', 'postgres'))
    if ($appId -notmatch '^[a-f0-9]{12,64}$' -or $postgresId -notmatch '^[a-f0-9]{12,64}$' -or $appId -eq $postgresId) {
        throw 'Compose no devolvio dos identificadores de contenedores distintos.'
    }
    $app = Get-OwnContainer $appId 'app' 'initial'
    $null = Get-OwnContainer $postgresId 'postgres' 'initial'
    Assert-Value 'Imagen de la aplicacion' $app.image $Image
    Assert-Value 'USER configurado' $app.user '10001:10001'
    $actualUid = Invoke-Docker -Arguments @('exec', $appId, 'id', '-u') -LogFile 'runtime-uid.log'
    Assert-Value 'UID efectivo' $actualUid '10001'
    Assert-Value 'Raiz de solo lectura' $app.readonlyRootfs $true
    Assert-Value 'Capabilities eliminadas' (@($app.capDrop) -contains 'ALL') $true
    Assert-Value 'No-new-privileges' (@($app.securityOpt) -contains 'no-new-privileges:true') $true
    $legacyTmpfs = $null -ne $app.tmpfs -and $null -ne $app.tmpfs.'/tmp'
    $tmpfsMounted = $legacyTmpfs -or @($app.mounts | Where-Object { $_.Type -eq 'tmpfs' -and $_.Destination -eq '/tmp' -and $_.RW }).Count -eq 1
    Assert-Value 'Tmpfs escribible en /tmp' $tmpfsMounted $true
    $null = Invoke-Docker -Arguments @('exec', $appId, 'test', '-w', '/tmp') -LogFile 'tmp-writable.log'
    Assert-Value 'Docker HEALTHCHECK saludable' $app.healthStatus 'healthy'
    Assert-Value 'Sin OOM inicial' $app.oomKilled $false
    $initialRestartCount = $app.restartCount
    $hashOutput = Invoke-Docker -Arguments @('exec', $appId, 'sha256sum', '/app/app.jar') -LogFile 'container-jar-sha256.log'
    if ($hashOutput -notmatch '^([a-f0-9]{64})\s+/app/app\.jar$') { throw 'No se obtuvo el SHA-256 del JAR del contenedor.' }
    $containerHash = $Matches[1]
    $nativeJar = Join-Path $projectPath 'target\demo-0.0.1.jar'
    $nativeHash = if (Test-Path -LiteralPath $nativeJar -PathType Leaf) {
        (Get-FileHash -LiteralPath $nativeJar -Algorithm SHA256).Hash.ToLowerInvariant()
    } else { $null }
    $jarHashes = [ordered]@{
        containerSha256 = $containerHash; nativeSha256 = $nativeHash
        equal = if ($nativeHash) { $containerHash -ceq $nativeHash } else { $null }
        note = 'Comparacion observacional entre el JAR del contenedor Linux y el JAR nativo disponible; no es una condicion de aprobacion.'
    }
    Invoke-HealthPhase 'health-up' 'UP'
    $dni = [string][System.Security.Cryptography.RandomNumberGenerator]::GetInt32(1000000000, 2147483647)
    $name = 'Docker Prueba'
    $created = Invoke-UserRequest -Method Post -Path '/users' -ExpectedStatus 201 -Body (@{ dni = $dni; name = $name } | ConvertTo-Json -Compress) -Phase 'create'
    Assert-Value 'Usuario creado tiene ID positivo' ($null -ne $created.id -and [long]$created.id -gt 0) $true
    foreach ($field in @('dni', 'name')) { Assert-Value "POST conserva $field" $created.$field (Get-Variable $field -ValueOnly) }
    $loaded = Invoke-UserRequest -Method Get -Path "/users/$($created.id)" -ExpectedStatus 200 -Phase 'read'
    foreach ($field in @('id', 'dni', 'name')) { Assert-Value "GET conserva $field" $loaded.$field $created.$field }

    $null = Get-OwnContainer $postgresId 'postgres' 'before-database-stop'
    $null = Invoke-Docker -Arguments @('stop', '--time', '15', $postgresId) -LogFile 'postgres-stop.log'
    Wait-Readiness 'DOWN'
    Invoke-HealthPhase 'health-down' 'DOWN'
    $duringOutage = Get-OwnContainer $appId 'app' 'database-down'
    Assert-Value 'App sigue ejecutandose sin PostgreSQL' $duringOutage.running $true
    Assert-Value 'App mantiene el mismo ID' $duringOutage.id $app.id
    Assert-Value 'App no se reinicia por fallo de base' $duringOutage.restartCount $initialRestartCount
    Assert-Value 'Sin OOM durante fallo de base' $duringOutage.oomKilled $false
    $null = Get-OwnContainer $postgresId 'postgres' 'before-database-start'
    $null = Invoke-Docker -Arguments @('start', $postgresId) -LogFile 'postgres-start.log'
    Wait-Readiness 'UP'
    Invoke-HealthPhase 'health-recovered' 'UP'
    $recovered = Invoke-UserRequest -Method Get -Path "/users/$($created.id)" -ExpectedStatus 200 -Phase 'recovered'
    foreach ($field in @('id', 'dni', 'name')) { Assert-Value "Tras recuperar PostgreSQL conserva $field" $recovered.$field $created.$field }
    $null = Get-OwnContainer $appId 'app' 'before-app-stop'
    $null = Invoke-Docker -Arguments @('stop', '--time', '25', $appId) -LogFile 'app-stop.log'
    $stopped = Get-OwnContainer $appId 'app' 'after-app-stop'
    $appLogs = Invoke-Docker -Arguments @('logs', '--timestamps', $appId) -LogFile 'app.log'
    Assert-Value 'App detenida' $stopped.running $false
    Assert-Value 'Salida compatible con SIGTERM o terminacion normal' ($stopped.exitCode -in @(0, 143)) $true
    Assert-Value 'Sin OOM al detenerse' $stopped.oomKilled $false
    Assert-Value 'Log confirma apagado graceful completo' ($appLogs -match 'Graceful shutdown complete') $true
    $workflowCompleted = $true
} catch {
    $failures.Add((Protect-Text $_.Exception.Message))
} finally {
    if ($cleanupRequired) {
        try {
            if ($project -notmatch '^devsu-verify-[a-f0-9]{8}$') { throw 'Nombre de proyecto inseguro para limpieza.' }
            $remainingIds = Invoke-Docker -Arguments @('ps', '-aq', '--filter', "label=com.docker.compose.project=$project")
            foreach ($id in @($remainingIds -split '\r?\n' | Where-Object { $_ })) {
                $format = '{"id":{{json .Id}},"name":{{json .Name}},"project":{{json (index .Config.Labels "com.docker.compose.project")}},"service":{{json (index .Config.Labels "com.docker.compose.service")}}}'
                $owner = (Invoke-Docker -Arguments @('inspect', '--format', $format, $id)) | ConvertFrom-Json
                if ($owner.project -cne $project -or $owner.name -notmatch ('^/' + [regex]::Escape($project) + '[-_]') -or
                    $owner.service -notin @('app', 'postgres')) { throw 'Contenedor ajeno detectado; limpieza cancelada.' }
                $null = Invoke-Docker -Arguments @('logs', '--timestamps', $id) -LogFile ("$($owner.service)-final.log")
            }
            $volumes = Invoke-Docker -Arguments @('volume', 'ls', '-q', '--filter', "label=com.docker.compose.project=$project")
            foreach ($volume in @($volumes -split '\r?\n' | Where-Object { $_ })) {
                $format = '{"name":{{json .Name}},"project":{{json (index .Labels "com.docker.compose.project")}}}'
                $owner = (Invoke-Docker -Arguments @('volume', 'inspect', '--format', $format, $volume)) | ConvertFrom-Json
                if ($owner.project -cne $project -or $owner.name -cne "${project}_postgres-data") {
                    throw 'Volumen ajeno detectado; limpieza cancelada.'
                }
            }
            $null = Invoke-Docker -Arguments ($compose + @('down', '--volumes', '--timeout', '25')) -LogFile 'compose-down.log'
            $leftContainers = Invoke-Docker -Arguments @('ps', '-aq', '--filter', "label=com.docker.compose.project=$project")
            $leftVolumes = Invoke-Docker -Arguments @('volume', 'ls', '-q', '--filter', "label=com.docker.compose.project=$project")
            Assert-Value 'Limpieza de contenedores propios' $leftContainers ''
            Assert-Value 'Limpieza de volumenes efimeros propios' $leftVolumes ''
            $cleanupSucceeded = $true
        } catch { $failures.Add('Limpieza: ' + (Protect-Text $_.Exception.Message)) }
    } else { $cleanupSucceeded = $true }
    foreach ($key in $previousEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($key, $previousEnvironment[$key], 'Process')
    }
    [ordered]@{
        startedAt = $startedAt; finishedAt = [DateTimeOffset]::Now.ToString('o')
        project = $project; image = $Image; baseUrl = $baseUrl
        appPort = $AppPort; postgresPort = $PostgresPort; containerPort = $ContainerPort
        passed = ($workflowCompleted -and $cleanupSucceeded -and $failures.Count -eq 0)
        cleanupSucceeded = $cleanupSucceeded; errors = $failures.ToArray()
        jarHashes = $jarHashes; checks = $checks.ToArray(); commands = $commands.ToArray(); snapshots = $snapshots.ToArray()
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $evidencePath 'docker-results.json') -Encoding utf8
}
if (-not $workflowCompleted -or -not $cleanupSucceeded -or $failures.Count -gt 0) {
    throw "La verificacion Docker no fue satisfactoria. Revisa $evidencePath\docker-results.json."
}
Write-Output "Docker verificado: $($checks.Count) comprobaciones; proyecto efimero $project eliminado. Evidencia: $evidencePath"
