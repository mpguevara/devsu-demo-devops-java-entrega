# Requiere PowerShell 7. Ejecuta el JAR con H2 en memoria y lo detiene al terminar.
[CmdletBinding()]
param(
    [string]$JarPath = (Join-Path $PSScriptRoot '..\target\demo-0.0.1.jar'),
    [ValidateRange(1024, 65535)][int]$Port = 8000,
    [string]$EvidenceDirectory = (Join-Path $PSScriptRoot '..\target\local-api-evidence')
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Este script requiere PowerShell 7.'
}
if (-not $env:JAVA_HOME) {
    throw 'Primero selecciona Java 17 con scripts\Use-Java17.ps1.'
}
if (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) {
    throw "El puerto $Port esta ocupado. Indica otro con -Port."
}
$javaExecutable = Join-Path $env:JAVA_HOME 'bin\java.exe'
$jar = Get-Item -LiteralPath $JarPath
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
$evidencePath = (Resolve-Path -LiteralPath $EvidenceDirectory).Path
$baseUrl = "http://127.0.0.1:$Port/api"
$checks = [System.Collections.Generic.List[object]]::new()
$startedAt = [DateTimeOffset]::Now.ToString('o')
$passed = $false
$application = $null

function Assert-ApiResponse {
    param([string]$Method, [string]$Path, [int]$ExpectedStatus, [string]$Body)
    $request = @{ Uri = "$baseUrl$Path"; Method = $Method; SkipHttpErrorCheck = $true; TimeoutSec = 15 }
    if ($Body) {
        $request.Body = $Body
        $request.ContentType = 'application/json'
    }
    $response = Invoke-WebRequest @request
    $checks.Add([ordered]@{
        method = $Method; url = "$baseUrl$Path"; expectedStatus = $ExpectedStatus
        actualStatus = [int]$response.StatusCode; passed = ([int]$response.StatusCode -eq $ExpectedStatus)
        responseBody = if ($response.Headers['Content-Type'] -match 'application/json') { $response.Content } else { $null }
    })
    if ([int]$response.StatusCode -ne $ExpectedStatus) {
        throw "$Method $Path devolvio $($response.StatusCode); se esperaba $ExpectedStatus."
    }
    return $response
}

try {
    $arguments = @(
        '-Xms64m', '-Xmx384m', '-jar', ('"' + $jar.FullName + '"'),
        '--spring.profiles.active=local',
        '--server.address=127.0.0.1', "--server.port=$Port",
        "--spring.datasource.url=jdbc:h2:mem:smoke-$PID;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE"
    )
    $application = Start-Process -FilePath $javaExecutable -ArgumentList $arguments -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $evidencePath 'application.stdout.log') `
        -RedirectStandardError (Join-Path $evidencePath 'application.stderr.log')

    $deadline = [DateTimeOffset]::Now.AddSeconds(90)
    $ready = $false
    while ([DateTimeOffset]::Now -lt $deadline -and -not $application.HasExited) {
        try {
            $probe = Invoke-WebRequest -Uri "$baseUrl/users" -TimeoutSec 2 -SkipHttpErrorCheck
            if ($probe.StatusCode -eq 200) { $ready = $true; break }
        } catch { }
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) { throw 'La aplicacion no inicio a tiempo. Revisa application.stdout.log y application.stderr.log.' }

    $list = Assert-ApiResponse -Method GET -Path '/users' -ExpectedStatus 200
    $null = Assert-ApiResponse -Method GET -Path '/users/1' -ExpectedStatus 200
    $sample = '{"dni":"9999999901","name":"Prueba DevOps"}'
    $created = Assert-ApiResponse -Method POST -Path '/users' -ExpectedStatus 201 -Body $sample
    $createdUser = $created.Content | ConvertFrom-Json
    $read = Assert-ApiResponse -Method GET -Path "/users/$($createdUser.id)" -ExpectedStatus 200
    $readUser = $read.Content | ConvertFrom-Json
    if ($readUser.name -ne 'Prueba DevOps' -or $readUser.dni -ne '9999999901') {
        throw 'La consulta no devolvio el usuario creado.'
    }
    $null = Assert-ApiResponse -Method POST -Path '/users' -ExpectedStatus 400 -Body $sample
    $null = Assert-ApiResponse -Method POST -Path '/users' -ExpectedStatus 400 -Body '{"dni":"","name":""}'
    $null = Assert-ApiResponse -Method GET -Path '/users/999999' -ExpectedStatus 404
    $null = Assert-ApiResponse -Method GET -Path '/swagger-ui.html' -ExpectedStatus 200
    $null = Assert-ApiResponse -Method GET -Path '/v3/api-docs' -ExpectedStatus 200
    $passed = $true
    Write-Output "API verificada: $($checks.Count) comprobaciones HTTP y lectura del usuario creado."
} finally {
    if ($application -and -not $application.HasExited) {
        Stop-Process -InputObject $application
        $application.WaitForExit()
    }
    [ordered]@{
        startedAt = $startedAt; finishedAt = [DateTimeOffset]::Now.ToString('o')
        jarSHA256 = (Get-FileHash -LiteralPath $jar.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        baseUrl = $baseUrl; passed = $passed; database = 'H2 in-memory, isolated, discarded on stop'
        checks = $checks.ToArray(); createdUserReadBack = $passed
        applicationStopped = ($null -ne $application -and $application.HasExited)
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidencePath 'http-results.json') -Encoding utf8
}
