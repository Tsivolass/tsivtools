$ErrorActionPreference = 'Stop'

$Root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$ServerData = Join-Path $Root 'server-data'
$Resources  = Join-Path $ServerData 'resources'
$Temp       = Join-Path $env:TEMP 'tsivtools-setup'

Write-Host 'tsivtools base server setup' -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path $ServerData, $Temp | Out-Null

if (Test-Path (Join-Path $Resources '[system]')) {
    Write-Host 'cfx-server-data already present, skipping download'
} else {
    Write-Host 'downloading cfx-server-data'
    $zip = Join-Path $Temp 'cfx-server-data.zip'
    Invoke-WebRequest -Uri 'https://github.com/citizenfx/cfx-server-data/archive/refs/heads/master.zip' -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $Temp -Force
    Copy-Item -Path (Join-Path $Temp 'cfx-server-data-master\*') -Destination $ServerData -Recurse -Force
    Write-Host 'cfx-server-data installed' -ForegroundColor Green
}

$Source = Join-Path (Split-Path -Parent $Root) 'tsivtools'
$Target = Join-Path $Resources 'tsivtools'

if (Test-Path $Source) {
    if (Test-Path $Target) { Remove-Item $Target -Recurse -Force }
    Copy-Item -Path $Source -Destination $Target -Recurse -Force
    Write-Host 'tsivtools copied into resources' -ForegroundColor Green
} else {
    Write-Host "could not find $Source" -ForegroundColor Yellow
}

$Cfg = Join-Path $ServerData 'server.cfg'
if (Test-Path $Cfg) {
    Write-Host 'server.cfg already exists, leaving it alone'
} else {
    Copy-Item -Path (Join-Path $Root 'server.cfg') -Destination $Cfg
    Write-Host 'server.cfg written' -ForegroundColor Green
}

Write-Host ''
Write-Host 'next steps:' -ForegroundColor Cyan
Write-Host '  1. put your licence key from https://portal.cfx.re into server-data\server.cfg'
Write-Host '  2. extract the FXServer artifacts to a folder next to this one'
Write-Host '  3. run:  <artifacts>\FXServer.exe +exec server.cfg   from inside server-data'
Write-Host '  4. join with  connect 127.0.0.1  in the FiveM F8 console'
