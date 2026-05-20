param(
    [string]$SpCompPath = "C:\Users\israe\sourcemodAPI\addons\sourcemod\scripting\spcomp.exe",
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$packageMapPath = Join-Path $root "plugin-package-map.json"
$sourceRoot = Join-Path $root "addons\\sourcemod"
$scriptingDir = Join-Path $sourceRoot "scripting"
$includeDir = Join-Path $scriptingDir "include"
$translationsDir = Join-Path $sourceRoot "translations"
$buildRoot = if ([string]::IsNullOrWhiteSpace($OutputRoot)) { Join-Path $root "build" } else { Join-Path $root $OutputRoot }
$artifactRoot = Join-Path $buildRoot "addons\\sourcemod"
$pluginsRoot = Join-Path $artifactRoot "plugins"
$compileLog = Join-Path $root ".tmp\build-windows-compile.log"

if (!(Test-Path $SpCompPath)) {
    throw "spcomp.exe no encontrado en: $SpCompPath"
}

if (!(Test-Path $packageMapPath)) {
    throw "No se encontró plugin-package-map.json en: $packageMapPath"
}

$packageMap = Get-Content -Raw -Path $packageMapPath | ConvertFrom-Json

function Get-PluginBucket {
    param([string]$PluginStem)

    if ($packageMap.anticheat -contains $PluginStem) {
        return "anticheat"
    }
    if ($packageMap.fixes -contains $PluginStem) {
        return "fixes"
    }
    return "optional"
}

if (Test-Path $buildRoot) {
    Remove-Item -Recurse -Force $buildRoot
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $compileLog) | Out-Null

New-Item -ItemType Directory -Force -Path $pluginsRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $pluginsRoot "anticheat") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $pluginsRoot "fixes") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $pluginsRoot "optional") | Out-Null
Set-Content -Path $compileLog -Value ""

$pluginSources = Get-ChildItem -Path $scriptingDir -Filter *.sp | Sort-Object Name
if ($pluginSources.Count -eq 0) {
    throw "No se encontraron plugins .sp en $scriptingDir"
}

foreach ($plugin in $pluginSources) {
    $pluginStem = [System.IO.Path]::GetFileNameWithoutExtension($plugin.Name)
    $bucket = Get-PluginBucket -PluginStem $pluginStem
    $outputPath = Join-Path $pluginsRoot "$bucket\$pluginStem.smx"

    Write-Host "Compilando $($plugin.Name) -> plugins/$bucket/$pluginStem.smx"

    $result = & $SpCompPath `
        $plugin.FullName `
        "-o$outputPath" `
        "-i$includeDir" `
        "-i$scriptingDir" `
        2>&1

    $result | Tee-Object -FilePath $compileLog -Append | Out-Host

    if (!(Test-Path $outputPath)) {
        throw "No se generó el binario esperado: $outputPath"
    }
}

Copy-Item -Recurse -Force $scriptingDir (Join-Path $artifactRoot "scripting")
Copy-Item -Recurse -Force $translationsDir (Join-Path $artifactRoot "translations")

Write-Host ""
Write-Host "Build local completado en: $buildRoot"
