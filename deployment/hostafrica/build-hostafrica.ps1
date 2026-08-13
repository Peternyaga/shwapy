[CmdletBinding()]
param(
    [string]$OutputDirectory = "dist",
    [string]$ReleaseName = "shwapy-hostafrica"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$deploymentDirectory = $PSScriptRoot
$repositoryRoot = (Resolve-Path (Join-Path $deploymentDirectory "..\..")).Path
$outputRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputDirectory))
$stageRoot = Join-Path $outputRoot "$ReleaseName-stage"
$archivePath = Join-Path $outputRoot "$ReleaseName.zip"
$checksumPath = "$archivePath.sha256"
$repositoryPrefix = $repositoryRoot.TrimEnd('\') + '\'

if ($outputRoot -ne $repositoryRoot -and -not $outputRoot.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputDirectory must resolve inside the repository."
}

if (Test-Path -LiteralPath $stageRoot) {
    $resolvedStage = (Resolve-Path -LiteralPath $stageRoot).Path
    $outputPrefix = $outputRoot.TrimEnd('\') + '\'
    if (-not $resolvedStage.StartsWith($outputPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove a staging directory outside the output directory."
    }
    Remove-Item -LiteralPath $resolvedStage -Recurse -Force
}

New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null

Push-Location (Join-Path $repositoryRoot "web")
try {
    npm ci
    if ($LASTEXITCODE -ne 0) {
        throw "npm ci failed with exit code $LASTEXITCODE."
    }
    npm run build
    if ($LASTEXITCODE -ne 0) {
        throw "npm run build failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

$backendRoot = Join-Path $repositoryRoot "backend"
$releaseDirectories = @(
    "app",
    "bootstrap",
    "config",
    "database",
    "public",
    "resources",
    "routes",
    "storage"
)

foreach ($directory in $releaseDirectories) {
    Copy-Item -LiteralPath (Join-Path $backendRoot $directory) -Destination $stageRoot -Recurse
}

$releaseFiles = @("artisan", "composer.json", "composer.lock")
foreach ($file in $releaseFiles) {
    Copy-Item -LiteralPath (Join-Path $backendRoot $file) -Destination $stageRoot
}

Copy-Item -Path (Join-Path $repositoryRoot "web\dist\*") -Destination (Join-Path $stageRoot "public") -Recurse -Force
Copy-Item -LiteralPath (Join-Path $deploymentDirectory "env.production.example") -Destination (Join-Path $stageRoot ".env.production.example")
Copy-Item -LiteralPath (Join-Path $deploymentDirectory "DEPLOYMENT.md") -Destination (Join-Path $stageRoot "DEPLOYMENT.md")
Copy-Item -LiteralPath (Join-Path $deploymentDirectory "install.sql") -Destination (Join-Path $stageRoot "install.sql")

Push-Location $stageRoot
try {
    composer install --no-dev --classmap-authoritative --no-interaction --prefer-dist
    if ($LASTEXITCODE -ne 0) {
        throw "composer install failed with exit code $LASTEXITCODE."
    }
    php artisan package:discover --ansi
    if ($LASTEXITCODE -ne 0) {
        throw "artisan package discovery failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
if (Test-Path -LiteralPath $checksumPath) {
    Remove-Item -LiteralPath $checksumPath -Force
}

Push-Location $stageRoot
try {
    tar -a -c -f $archivePath .
    if ($LASTEXITCODE -ne 0) {
        throw "ZIP creation failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}
$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksumPath -Value "$hash  $ReleaseName.zip" -Encoding ascii

Write-Host "Created $archivePath"
Write-Host "Created $checksumPath"
