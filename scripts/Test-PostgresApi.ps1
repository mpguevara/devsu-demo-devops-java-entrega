# Requiere PowerShell 7, Java 17 y una base PostgreSQL de prueba nueva y vacia.
# Deja los dos usuarios de prueba en la base; no borra ni restablece datos.
[CmdletBinding()]
param(
    [string]$JarPath = (Join-Path $PSScriptRoot '..\target\demo-0.0.1.jar'),
    [ValidateRange(1024, 65535)][int]$PortA = 8001,
    [ValidateRange(1024, 65535)][int]$PortB = 8002,
    [string]$EvidenceDirectory = (Join-Path $PSScriptRoot '..\target\postgres-api-evidence'),
    [string]$PsqlPath
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Este script requiere PowerShell 7.' }
foreach ($variable in @('JAVA_HOME', 'NAME_DB', 'USERNAME_DB', 'PASSWORD_DB')) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($variable))) {
        throw "Define $variable antes de ejecutar esta comprobacion."
    }
}
if ($PortA -eq $PortB) { throw 'PortA y PortB deben ser distintos.' }
foreach ($port in @($PortA, $PortB)) {
    if (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) {
        throw "El puerto $port esta ocupado. Selecciona otro puerto."
    }
}

# No se aceptan credenciales ni parametros adicionales dentro de la URL JDBC.
if ($env:NAME_DB -notmatch '^jdbc:postgresql://[^/?#]+/[A-Za-z0-9_-]+$') {
    throw 'NAME_DB debe tener formato jdbc:postgresql://host:puerto/base, sin credenciales ni parametros.'
}
$databaseUri = [Uri]($env:NAME_DB.Substring(5))
if ($databaseUri.UserInfo) { throw 'Las credenciales deben estar en variables de entorno.' }
$databaseHost = $databaseUri.Host
$databasePort = if ($databaseUri.Port -gt 0) { $databaseUri.Port } else { 5432 }
$databaseName = $databaseUri.AbsolutePath.TrimStart('/')
$nativePsql = -not [string]::IsNullOrWhiteSpace($PsqlPath)
if ($nativePsql) {
    $psqlExecutable = (Get-Command -Name $PsqlPath -CommandType Application -ErrorAction Stop).Source
} else {
    $null = Get-Command docker -CommandType Application -ErrorAction Stop
    $composePort = if ($env:POSTGRES_PORT) { [int]$env:POSTGRES_PORT } else { 5432 }
    if ($databaseHost -notin @('localhost', '127.0.0.1') -or $databasePort -ne $composePort -or
        $databaseName -ne 'devsu' -or $env:USERNAME_DB -ne 'devsu') {
        throw 'Sin PsqlPath, usa la base devsu del servicio Compose local con usuario devsu y su puerto POSTGRES_PORT (5432 por defecto).'
    }
}

$javaExecutable = Join-Path $env:JAVA_HOME 'bin\java.exe'
if (-not (Test-Path -LiteralPath $javaExecutable -PathType Leaf)) { throw 'JAVA_HOME no contiene bin\java.exe.' }
$jar = Get-Item -LiteralPath $JarPath -ErrorAction Stop
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
$evidencePath = (Resolve-Path -LiteralPath $EvidenceDirectory).Path
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$checks = [System.Collections.Generic.List[object]]::new()
$applications = [System.Collections.Generic.List[object]]::new()
$baseA = "http://127.0.0.1:$PortA/api"
$baseB = "http://127.0.0.1:$PortB/api"
$startedAt = [DateTimeOffset]::Now.ToString('o')
$jarHash = (Get-FileHash -LiteralPath $jar.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
$passed = $false
$failure = $null
$originalReadAcrossReplicas = $false
$originalSurvivedRestart = $false
$previousPgPassword = [Environment]::GetEnvironmentVariable('PGPASSWORD', 'Process')
$previousPgConnectTimeout = [Environment]::GetEnvironmentVariable('PGCONNECT_TIMEOUT', 'Process')
$httpClient = $null

function Protect-Text {
    param([string]$Value)
    if ($null -eq $Value) { return $null }
    return $Value.Replace($env:PASSWORD_DB, '[REDACTED]')
}

function Assert-Value {
    param([string]$Name, $Actual, $Expected)
    $ok = $Actual -eq $Expected
    $checks.Add([ordered]@{
        timestamp = [DateTimeOffset]::Now.ToString('o'); type = 'assertion'; name = $Name
        expected = $Expected; actual = $Actual; passed = $ok
    })
    if (-not $ok) { throw "Fallo la comprobacion: $Name." }
}

function Assert-Sql {
    param([string]$Name, [string]$Sql, [string]$Expected)
    if ($nativePsql) {
        $output = & $psqlExecutable -X -w -h $databaseHost -p $databasePort -U $env:USERNAME_DB `
            -d $databaseName -v ON_ERROR_STOP=1 -Atq -c $Sql 2>&1
    } else {
        $output = & docker compose --project-directory $projectPath exec -T postgres psql `
            -X -w -U devsu -d devsu -v ON_ERROR_STOP=1 -Atq -c $Sql 2>&1
    }
    $exitCode = $LASTEXITCODE
    $actual = (($output | ForEach-Object { $_.ToString() }) -join "`n").Trim()
    $ok = $exitCode -eq 0 -and $actual -ceq $Expected
    $checks.Add([ordered]@{
        timestamp = [DateTimeOffset]::Now.ToString('o'); type = 'sql'; name = $Name
        sql = $Sql; expected = $Expected; actual = (Protect-Text $actual)
        exitCode = $exitCode; passed = $ok
    })
    if (-not $ok) { throw "Fallo la comprobacion SQL: $Name. Revisa http-results.json." }
}

function Start-Api {
    param([string]$Label, [int]$Port)
    $stdout = Join-Path $evidencePath "$Label.stdout.log"
    $stderr = Join-Path $evidencePath "$Label.stderr.log"
    $arguments = @(
        '-Xms64m', '-Xmx256m', '-jar', ('"' + $jar.FullName + '"'),
        '--spring.profiles.active=postgres', '--server.address=127.0.0.1', "--server.port=$Port"
    )
    $process = Start-Process -FilePath $javaExecutable -ArgumentList $arguments -PassThru -WindowStyle Hidden `
        -WorkingDirectory $projectPath -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $applications.Add([ordered]@{ label = $Label; process = $process; stdout = $stdout; stderr = $stderr })
    return $process
}

function Wait-Api {
    param($Process, [string]$BaseUrl, [DateTimeOffset]$Deadline)
    while ([DateTimeOffset]::Now -lt $Deadline -and -not $Process.HasExited) {
        try {
            $response = Invoke-WebRequest -Uri "$BaseUrl/users" -SkipHttpErrorCheck -TimeoutSec 2
            if ($response.StatusCode -eq 200) {
                $checks.Add([ordered]@{
                    timestamp = [DateTimeOffset]::Now.ToString('o'); type = 'readiness'
                    url = "$BaseUrl/users"; actualStatus = 200; passed = $true
                })
                return
            }
        } catch { }
        Start-Sleep -Milliseconds 300
    }
    $checks.Add([ordered]@{
        timestamp = [DateTimeOffset]::Now.ToString('o'); type = 'readiness'
        url = "$BaseUrl/users"; passed = $false; processExited = $Process.HasExited
    })
    throw "La aplicacion en $BaseUrl no estuvo disponible dentro del limite. Revisa sus logs."
}

function Assert-Api {
    param([string]$BaseUrl, [string]$Method, [string]$Path, [int]$ExpectedStatus, [string]$Body)
    $request = @{ Uri = "$BaseUrl$Path"; Method = $Method; SkipHttpErrorCheck = $true; TimeoutSec = 15 }
    if ($PSBoundParameters.ContainsKey('Body')) {
        $request.Body = $Body
        $request.ContentType = 'application/json'
    }
    $response = Invoke-WebRequest @request
    $ok = [int]$response.StatusCode -eq $ExpectedStatus
    $checks.Add([ordered]@{
        timestamp = [DateTimeOffset]::Now.ToString('o'); type = 'http'; method = $Method; url = "$BaseUrl$Path"
        expectedStatus = $ExpectedStatus; actualStatus = [int]$response.StatusCode; passed = $ok
        responseBody = (Protect-Text $response.Content)
    })
    if (-not $ok) { throw "$Method $Path devolvio $($response.StatusCode); se esperaba $ExpectedStatus." }
    return $response
}

try {
    if ($nativePsql) {
        $env:PGPASSWORD = $env:PASSWORD_DB
        $env:PGCONNECT_TIMEOUT = '10'
    }
    Assert-Sql -Name 'La base no contiene users ni historial Flyway' `
        -Sql "SELECT (to_regclass('public.users') IS NULL AND to_regclass('public.flyway_schema_history') IS NULL)::text;" -Expected 'true'
    Assert-Sql -Name 'La base no contiene tablas de aplicacion preexistentes' `
        -Sql "SELECT count(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema') AND table_type = 'BASE TABLE';" -Expected '0'

    # Se lanzan ambas JVM antes de esperar a que cualquiera termine de arrancar.
    $appA = Start-Api -Label 'app-a-start' -Port $PortA
    $appB = Start-Api -Label 'app-b-start' -Port $PortB
    $startupDeadline = [DateTimeOffset]::Now.AddSeconds(90)
    Wait-Api -Process $appA -BaseUrl $baseA -Deadline $startupDeadline
    Wait-Api -Process $appB -BaseUrl $baseB -Deadline $startupDeadline

    Assert-Sql -Name 'Flyway aplico V1 exactamente una vez' `
        -Sql "SELECT count(*) FROM public.flyway_schema_history WHERE version = '1' AND success;" -Expected '1'
    Assert-Sql -Name 'Solo existe la migracion V1' -Sql 'SELECT count(*) FROM public.flyway_schema_history;' -Expected '1'
    Assert-Sql -Name 'La tabla users inicia vacia' -Sql 'SELECT count(*) FROM public.users;' -Expected '0'
    $initialA = Assert-Api -BaseUrl $baseA -Method GET -Path '/users' -ExpectedStatus 200
    $initialB = Assert-Api -BaseUrl $baseB -Method GET -Path '/users' -ExpectedStatus 200
    Assert-Value -Name 'La replica A inicia sin usuarios' -Actual @($initialA.Content | ConvertFrom-Json).Count -Expected 0
    Assert-Value -Name 'La replica B inicia sin usuarios' -Actual @($initialB.Content | ConvertFrom-Json).Count -Expected 0

    $sample = '{"dni":"9999999901","name":"Prueba compartida"}'
    $created = Assert-Api -BaseUrl $baseA -Method POST -Path '/users' -ExpectedStatus 201 -Body $sample
    $createdUser = $created.Content | ConvertFrom-Json
    if ($null -eq $createdUser.id -or [long]$createdUser.id -le 0) { throw 'El POST no devolvio un ID valido.' }
    $read = Assert-Api -BaseUrl $baseB -Method GET -Path "/users/$($createdUser.id)" -ExpectedStatus 200
    $readUser = $read.Content | ConvertFrom-Json
    Assert-Value -Name 'B lee el ID creado en A' -Actual $readUser.id -Expected $createdUser.id
    Assert-Value -Name 'B lee el DNI creado en A' -Actual $readUser.dni -Expected '9999999901'
    Assert-Value -Name 'B lee el nombre creado en A' -Actual $readUser.name -Expected 'Prueba compartida'
    $originalReadAcrossReplicas = $true
    $null = Assert-Api -BaseUrl $baseB -Method POST -Path '/users' -ExpectedStatus 400 -Body $sample
    $null = Assert-Api -BaseUrl $baseA -Method POST -Path '/users' -ExpectedStatus 400 -Body ''
    $null = Assert-Api -BaseUrl $baseA -Method POST -Path '/users' -ExpectedStatus 400 -Body '{"dni":"","name":""}'
    $null = Assert-Api -BaseUrl $baseB -Method GET -Path '/users/9223372036854775807' -ExpectedStatus 404

    # SendAsync inicia los dos POST sin esperar la respuesta del primero.
    $httpClient = [System.Net.Http.HttpClient]::new()
    $httpClient.Timeout = [TimeSpan]::FromSeconds(20)
    $concurrentBody = '{"dni":"9999999902","name":"Prueba concurrente"}'
    $pending = [System.Collections.Generic.List[object]]::new()
    foreach ($base in @($baseA, $baseB)) {
        $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, "$base/users")
        $request.Content = [System.Net.Http.StringContent]::new($concurrentBody, [Text.Encoding]::UTF8, 'application/json')
        $pending.Add([ordered]@{ url = "$base/users"; request = $request; task = $httpClient.SendAsync($request) })
    }
    $statuses = [System.Collections.Generic.List[int]]::new()
    foreach ($item in $pending) {
        $response = $null
        try {
            $response = $item.task.GetAwaiter().GetResult()
            $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $status = [int]$response.StatusCode
            $statuses.Add($status)
            $checks.Add([ordered]@{
                timestamp = [DateTimeOffset]::Now.ToString('o'); type = 'http-concurrent'
                method = 'POST'; url = $item.url; expectedStatuses = @(201, 400)
                actualStatus = $status; responseBody = (Protect-Text $body); passed = $status -in @(201, 400)
            })
        } finally {
            if ($response) { $response.Dispose() }
            $item.request.Dispose()
        }
    }
    Assert-Value -Name 'Los POST concurrentes producen exactamente 201 y 400' `
        -Actual (($statuses | Sort-Object) -join ',') -Expected '201,400'
    Assert-Sql -Name 'La restriccion unica conserva un usuario concurrente' `
        -Sql "SELECT count(*) FROM public.users WHERE dni = '9999999902';" -Expected '1'
    Assert-Sql -Name 'Hay exactamente dos usuarios antes del reinicio' -Sql 'SELECT count(*) FROM public.users;' -Expected '2'

    Stop-Process -InputObject $appA
    if (-not $appA.WaitForExit(10000)) { throw 'La replica A no se detuvo dentro del limite.' }
    Assert-Value -Name 'B continua ejecutandose al detener A' -Actual $appB.HasExited -Expected $false
    $null = Assert-Api -BaseUrl $baseB -Method GET -Path "/users/$($createdUser.id)" -ExpectedStatus 200
    $appA = Start-Api -Label 'app-a-restart' -Port $PortA
    Wait-Api -Process $appA -BaseUrl $baseA -Deadline ([DateTimeOffset]::Now.AddSeconds(90))
    $afterRestart = Assert-Api -BaseUrl $baseA -Method GET -Path "/users/$($createdUser.id)" -ExpectedStatus 200
    $persistedUser = $afterRestart.Content | ConvertFrom-Json
    Assert-Value -Name 'El ID original se conserva tras reiniciar A' -Actual $persistedUser.id -Expected $createdUser.id
    Assert-Value -Name 'El DNI original se conserva tras reiniciar A' -Actual $persistedUser.dni -Expected '9999999901'
    Assert-Value -Name 'El nombre original se conserva tras reiniciar A' -Actual $persistedUser.name -Expected 'Prueba compartida'
    Assert-Sql -Name 'Los dos usuarios sobreviven al reinicio' -Sql 'SELECT count(*) FROM public.users;' -Expected '2'
    Assert-Sql -Name 'El reinicio no vuelve a aplicar V1' `
        -Sql "SELECT count(*) FROM public.flyway_schema_history WHERE version = '1' AND success;" -Expected '1'
    Assert-Sql -Name 'El historial sigue conteniendo solo V1' -Sql 'SELECT count(*) FROM public.flyway_schema_history;' -Expected '1'
    Assert-Value -Name 'B sigue ejecutandose despues del reinicio de A' -Actual $appB.HasExited -Expected $false
    $originalSurvivedRestart = $true
    $passed = $true
} catch {
    $failure = Protect-Text $_.Exception.Message
    throw
} finally {
    if ($httpClient) { $httpClient.Dispose() }
    $processResults = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in $applications) {
        try {
            if (-not $entry.process.HasExited) {
                Stop-Process -InputObject $entry.process
                if (-not $entry.process.WaitForExit(10000)) { throw 'El proceso no termino dentro del limite.' }
            }
        } catch {
            $passed = $false
            if (-not $failure) { $failure = "No se pudo detener el proceso propio $($entry.label)." }
        }
        $processResults.Add([ordered]@{
            label = $entry.label; processId = $entry.process.Id; stopped = $entry.process.HasExited
            stdout = [IO.Path]::GetFileName($entry.stdout); stderr = [IO.Path]::GetFileName($entry.stderr)
        })
        # Defensa adicional: retirar el valor secreto si alguna dependencia lo escribiera en un log.
        foreach ($log in @($entry.stdout, $entry.stderr)) {
            try {
                if (Test-Path -LiteralPath $log -PathType Leaf) {
                    $logText = [IO.File]::ReadAllText($log)
                    if ($logText.Contains($env:PASSWORD_DB)) {
                        [IO.File]::WriteAllText($log, (Protect-Text $logText), [Text.UTF8Encoding]::new($false))
                    }
                }
            } catch {
                $passed = $false
                if (-not $failure) { $failure = "No se pudo revisar el log de $($entry.label)." }
            }
        }
    }
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $previousPgPassword, 'Process')
    [Environment]::SetEnvironmentVariable('PGCONNECT_TIMEOUT', $previousPgConnectTimeout, 'Process')
    [ordered]@{
        startedAt = $startedAt; finishedAt = [DateTimeOffset]::Now.ToString('o'); jarSHA256 = $jarHash
        database = 'PostgreSQL shared, initially empty; test users retained; no data reset'
        sqlTransport = if ($nativePsql) { 'native psql' } else { 'docker compose exec postgres psql' }
        baseUrls = @($baseA, $baseB); passed = $passed; failure = $failure
        createdUserReadAcrossReplicas = $originalReadAcrossReplicas; createdUserSurvivedRestart = $originalSurvivedRestart
        applicationStopped = $applications.Count -gt 0 -and @($processResults | Where-Object { -not $_.stopped }).Count -eq 0
        processes = $processResults.ToArray(); checks = $checks.ToArray()
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $evidencePath 'http-results.json') -Encoding utf8
}

if (-not $passed) { throw 'La comprobacion no termino correctamente. Revisa http-results.json.' }
Write-Output "PostgreSQL verificado: $($checks.Count) comprobaciones reales; dos JVM, lectura compartida, unicidad, persistencia tras reiniciar A y procesos detenidos."
