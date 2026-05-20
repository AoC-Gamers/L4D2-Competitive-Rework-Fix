param(
    [string]$SourceModVersion = "1.12"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$tmpRoot = Join-Path $root ".tmp"
$workDir = Join-Path $tmpRoot "sourcemod-windows"
$archivePath = Join-Path $tmpRoot "sourcemod-windows.zip"
$archiveUrl = "https://www.sourcemod.net/latest.php?os=windows&version=$SourceModVersion"

if (Test-Path $workDir) {
    Remove-Item -Recurse -Force $workDir
}

New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

Write-Host "Descargando SourceMod para Windows desde: $archiveUrl"
Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath

Expand-Archive -LiteralPath $archivePath -DestinationPath $workDir -Force

Write-Host "Dependencias de Windows listas en: $workDir"
