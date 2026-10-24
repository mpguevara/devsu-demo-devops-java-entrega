[CmdletBinding()]
param(
    [string]$JdkHome = (Join-Path $env:LOCALAPPDATA 'DevsuDevOps\tools\jdk-17.0.20.1+1')
)

$ErrorActionPreference = 'Stop'
$javaExecutable = Join-Path $JdkHome 'bin\java.exe'
if (-not (Test-Path -LiteralPath $javaExecutable) -or
    -not (Test-Path -LiteralPath (Join-Path $JdkHome 'bin\javac.exe'))) {
    throw 'No se encontro un JDK completo. Ejecuta Install-Java17.ps1 o indica -JdkHome.'
}

$javaProperties = (& $javaExecutable -XshowSettings:properties -version 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -or $javaProperties -notmatch 'java\.specification\.version\s*=\s*17\s') {
    throw "El JDK seleccionado debe ser Java 17: $JdkHome"
}

# Solo afecta a este proceso de PowerShell y a los comandos que lance.
$env:JAVA_HOME = (Resolve-Path -LiteralPath $JdkHome).Path
$env:Path = (Join-Path $env:JAVA_HOME 'bin') + [IO.Path]::PathSeparator + $env:Path
& $javaExecutable -version
Write-Output "JAVA_HOME seleccionado para esta terminal: $env:JAVA_HOME"
