# PowerShell packaging script for Waypoint Windows
param (
    [switch]$Build = $true
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$helmDir = Split-Path -Parent $scriptDir
Set-Location $helmDir

# Extract version from pubspec.yaml
$pubspec = Get-Content "pubspec.yaml"
$versionLine = $pubspec | Where-Object { $_ -match "^version:\s*([^\s+]+)" }
$version = $matches[1]

Write-Host "Packaging Waypoint Windows v$version..." -ForegroundColor Green

if ($Build) {
    Write-Host "Building Windows release..." -ForegroundColor Cyan
    flutter build windows --release
}

$releaseDir = Join-Path $helmDir "build\windows\x64\runner\Release"
if (-not (Test-Path $releaseDir)) {
    Write-Error "Release build directory not found: $releaseDir"
    exit 1
}

# 1. Try Inno Setup compiler (ISCC)
$isccPaths = @(
    "iscc.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
    "${env:LocalAppData}\Programs\Inno Setup 6\ISCC.exe"
)

$iscc = $null
foreach ($p in $isccPaths) {
    if (Get-Command $p -ErrorAction SilentlyContinue) {
        $iscc = (Get-Command $p).Source
        break
    } elseif (Test-Path $p) {
        $iscc = $p
        break
    }
}

$installerDir = Join-Path $helmDir "build\windows\installer"
New-Item -ItemType Directory -Force -Path $installerDir | Out-Null

if ($iscc) {
    Write-Host "Compiling setup installer with Inno Setup ($iscc)..." -ForegroundColor Cyan
    $issFile = Join-Path $helmDir "windows\installer\waypoint_setup.iss"
    & $iscc "/DMyAppVersion=$version" $issFile
    $setupExe = Join-Path $installerDir "Waypoint-v$version-Setup.exe"
    if (Test-Path $setupExe) {
        Write-Host "Created single setup installer: $setupExe" -ForegroundColor Green
    }
} else {
    Write-Host "Inno Setup not detected. Install via: winget install JR.InnoSetup" -ForegroundColor Yellow
    # Fallback: Create clean standalone ZIP
    $zipPath = Join-Path $installerDir "waypoint-v$version-windows.zip"
    Write-Host "Creating standalone release archive: $zipPath" -ForegroundColor Cyan
    Compress-Archive -Path "$releaseDir\*" -DestinationPath $zipPath -Force
    Write-Host "Created archive: $zipPath" -ForegroundColor Green
}

