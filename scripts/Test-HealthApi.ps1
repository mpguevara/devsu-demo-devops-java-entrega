# Requiere PowerShell 7 y una API ya ejecutandose. No administra procesos ni bases de datos.
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$BaseUrl = 'http://127.0.0.1:8000/api',
    [ValidateSet('UP', 'DOWN')]
    [string]$ExpectedReadiness = 'UP',
    [string]$EvidenceDirectory = (Join-Path $PSScriptRoot '..\target\health-api-evidence')
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Este script requiere PowerShell 7.'
}
$apiUri = [Uri]$BaseUrl
if (-not $apiUri.IsAbsoluteUri -or $apiUri.Scheme -notin @('http', 'https') -or
    $apiUri.UserInfo -or $apiUri.Query -or $apiUri.Fragment) {
    throw 'BaseUrl debe ser una URL HTTP(S) absoluta sin credenciales, parametros ni fragmentos.'
}
$BaseUrl = $BaseUrl.TrimEnd('/')
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
$evidencePath = (Resolve-Path -LiteralPath $EvidenceDirectory).Path
$checks = [System.Collections.Generic.List[object]]::new()
$startedAt = [DateTimeOffset]::Now.ToString('o')
$passed = $false

function Test-HealthResponse {
    param(
        [string]$Path,
        [int]$ExpectedStatus,
        [string]$ExpectedHealthStatus
    )

    $timestamp = [DateTimeOffset]::Now.ToString('o')
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $actualStatus = $null
    $actualHealthStatus = $null
    $responseBody = $null
    $responseBodyOmitted = $false
    $problems = [System.Collections.Generic.List[string]]::new()
    try {
        $response = Invoke-WebRequest -Uri "$BaseUrl$Path" -Method Get `
            -Headers @{ Accept = 'application/json' } -TimeoutSec 10 -SkipHttpErrorCheck
        $actualStatus = [int]$response.StatusCode

        # Si un endpoint interno se expuso por error, no guardar su contenido potencialmente sensible.
        if ($ExpectedHealthStatus -or $actualStatus -eq 404) {
            $responseBody = [string]$response.Content
        } else {
            $responseBodyOmitted = $true
        }

        if ($actualStatus -ne $ExpectedStatus) {
            $problems.Add("HTTP $actualStatus; se esperaba $ExpectedStatus.")
        }

        if ($ExpectedHealthStatus) {
            if ([string]$response.Headers['Content-Type'] -notmatch 'application/(?:[a-z0-9.+-]+\+)?json') {
                $problems.Add('La respuesta de salud no declara un Content-Type JSON.')
            }
            $health = $response.Content | ConvertFrom-Json -AsHashtable
            if ($health -isnot [System.Collections.IDictionary]) {
                $problems.Add('La respuesta de salud no es un objeto JSON.')
            } else {
                $actualHealthStatus = $health['status']
                if ($actualHealthStatus -ne $ExpectedHealthStatus) {
                    $problems.Add("Estado de salud '$actualHealthStatus'; se esperaba '$ExpectedHealthStatus'.")
                }
                if ($health.Contains('components') -or $health.Contains('details')) {
                    $problems.Add('La respuesta de salud expone components o details.')
                }
            }
        }
    } catch {
        $problems.Add($_.Exception.Message)
    } finally {
        $stopwatch.Stop()
        $checks.Add([ordered]@{
            timestamp = $timestamp
            method = 'GET'
            url = "$BaseUrl$Path"
            expectedStatus = $ExpectedStatus
            actualStatus = $actualStatus
            expectedHealthStatus = $ExpectedHealthStatus
            actualHealthStatus = $actualHealthStatus
            elapsedMilliseconds = $stopwatch.ElapsedMilliseconds
            responseBody = $responseBody
            responseBodyOmitted = $responseBodyOmitted
            passed = ($problems.Count -eq 0)
            errors = $problems.ToArray()
        })
    }
}

try {
    Test-HealthResponse -Path '/actuator/health/liveness' -ExpectedStatus 200 -ExpectedHealthStatus 'UP'
    $readinessStatusCode = if ($ExpectedReadiness -eq 'UP') { 200 } else { 503 }
    Test-HealthResponse -Path '/actuator/health/readiness' -ExpectedStatus $readinessStatusCode `
        -ExpectedHealthStatus $ExpectedReadiness
    foreach ($endpoint in @('env', 'configprops', 'metrics')) {
        Test-HealthResponse -Path "/actuator/$endpoint" -ExpectedStatus 404
    }

    $failedChecks = @($checks | Where-Object { -not $_.passed })
    $passed = ($failedChecks.Count -eq 0 -and $checks.Count -eq 5)
    if (-not $passed) {
        throw "Fallaron $($failedChecks.Count) de $($checks.Count) comprobaciones. Revisa http-results.json."
    }
    Write-Output "Salud verificada: $($checks.Count) comprobaciones; liveness UP y readiness $ExpectedReadiness."
} finally {
    [ordered]@{
        startedAt = $startedAt
        finishedAt = [DateTimeOffset]::Now.ToString('o')
        baseUrl = $BaseUrl
        expectedReadiness = $ExpectedReadiness
        passed = $passed
        checks = $checks.ToArray()
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidencePath 'http-results.json') -Encoding utf8
}
