<#
.SYNOPSIS
  Automated multi-platform build runner for Waypoint.
.DESCRIPTION
  Builds Windows (with setup installer), Android APK (with versioned naming),
  and Web releases.
.EXAMPLE
  .\build.ps1 -Target all
  .\build.ps1 -Target windows
  .\build.ps1 -Target apk
  .\build.ps1 -Target web
#>
param(
    [ValidateSet("all", "windows", "apk", "web")]
    [string]$Target = "all"
)

$ErrorActionPreference = "Stop"

$helmDir = $PSScriptRoot
Set-Location $helmDir

# Extract version from pubspec.yaml
$pubspec = Get-Content "pubspec.yaml"
$versionLine = $pubspec | Where-Object { $_ -match "^version:\s*([^\s+]+)" }
$version = $matches[1]

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Building Waypoint Workspace v$version" -ForegroundColor Green
Write-Host " Target: $Target" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$artifacts = @()

# 1. Build Windows
if ($Target -eq "windows" -or $Target -eq "all") {
    Write-Host "`n[1/3] Building Windows Release & Setup Installer..." -ForegroundColor Yellow
    flutter build windows --release

    $setupPath = Join-Path $helmDir "build\windows\installer\Waypoint-v$version-Setup.exe"
    $exePath = Join-Path $helmDir "build\windows\x64\runner\Release\waypoint-v$version.exe"

    if (Test-Path $setupPath) {
        $artifacts += [PSCustomObject]@{ Platform = "Windows Setup"; File = $setupPath }
    } elseif (Test-Path $exePath) {
        $artifacts += [PSCustomObject]@{ Platform = "Windows Exe"; File = $exePath }
    }
}

# 2. Build Android APK
if ($Target -eq "apk" -or $Target -eq "all") {
    Write-Host "`n[2/3] Building Android Release APK..." -ForegroundColor Yellow
    flutter build apk --release

    $apkPath = Join-Path $helmDir "build\app\outputs\flutter-apk\waypoint-v$version.apk"
    if (-not (Test-Path $apkPath)) {
        $apkPath = Join-Path $helmDir "build\app\outputs\apk\release\waypoint-v$version.apk"
    }

    if (Test-Path $apkPath) {
        $artifacts += [PSCustomObject]@{ Platform = "Android APK"; File = $apkPath }
    }
}

# 3. Build Web
if ($Target -eq "web" -or $Target -eq "all") {
    Write-Host "`n[3/3] Building Web Release Bundle..." -ForegroundColor Yellow
    flutter build web --release --pwa-strategy=none --no-wasm-dry-run

    $webPath = Join-Path $helmDir "build\web"
    if (Test-Path $webPath) {
        $artifacts += [PSCustomObject]@{ Platform = "Web"; File = $webPath }
    }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host " Build Complete! Artifacts:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
foreach ($item in $artifacts) {
    Write-Host " * $($item.Platform): $($item.File)" -ForegroundColor White
}
Write-Host ""
