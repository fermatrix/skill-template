# =============================================================================
# build-skill.ps1 — Skill distribution builder
# =============================================================================
#
# USAGE
#   .\build-skill.ps1 -Version 1.0.0
#
# WHAT IT PRODUCES
#   releases_public/
#     skill-{name}-v{version}-public.zip   ← No credentials. Safe for GitHub.
#
#   releases_private/                       ← Gitignored. NEVER push to GitHub.
#     skill-{name}-v{version}.zip          ← MASTER: full .env (all clients)
#     skill-{name}-v{version}_{CLIENT}.zip ← One ZIP per client, only their vars
#
# FOLDER STRUCTURE REQUIRED
#   skill-{name}/
#     build-skill.ps1         ← this file
#     SKILL.md
#     README.md
#     LICENSE
#     .env.example
#     scripts/
#     releases_public/        ← created automatically, tracked by git
#     releases_private/       ← created automatically, gitignored
#       .env                  ← credentials source (place manually, never commit)
#
# ENV FILE CONVENTION
#   File location : releases_private/.env
#   Variable pattern: {SKILL}_{CLIENT}_{VARNAME}
#
#   The prefix is derived from the folder name automatically:
#     skill-holded   → HOLDED_
#     skill-odoo     → ODOO_
#     skill-mailgun  → MAILGUN_
#
#   Example — skill-holded/releases_private/.env:
#     HOLDED_SPIRAL_API_KEY=abc123
#     HOLDED_REALFLOOW_API_KEY=def456
#   → Generates:
#     skill-holded-v1.0.0_SPIRAL.zip    (contains only HOLDED_SPIRAL_* vars)
#     skill-holded-v1.0.0_REALFLOOW.zip (contains only HOLDED_REALFLOOW_* vars)
#
#   Example — skill-odoo/releases_private/.env:
#     ODOO_CLIENT1_URL=https://client1.odoo.com
#     ODOO_CLIENT1_DB=client1
#     ODOO_CLIENT1_USER=admin@client1.com
#     ODOO_CLIENT1_APIKEY=abc123
#     ODOO_CLIENT2_URL=https://client2.odoo.com
#     ODOO_CLIENT2_DB=client2
#     ODOO_CLIENT2_USER=admin@client2.com
#     ODOO_CLIENT2_APIKEY=def456
#   → Generates:
#     skill-odoo-v1.0.0_CLIENT1.zip     (ODOO_CLIENT1_URL + DB + USER + APIKEY)
#     skill-odoo-v1.0.0_CLIENT2.zip  (ODOO_CLIENT2_URL + DB + USER + APIKEY)
#
# ADDING A NEW CLIENT
#   Add their variables to releases_private/skill-{name}.env and re-run.
#   No changes to this script needed — detection is automatic.
#
# =============================================================================

param([string]$Version = "")

Add-Type -AssemblyName System.IO.Compression.FileSystem

function New-UnixZip {
    param([string]$SourceDir, [string]$ZipPath)

    $destDir = Split-Path -Path $ZipPath
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force > $null
    }

    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    $zip = [System.IO.Compression.ZipFile]::Open($ZipPath, 'Create')
    Get-ChildItem -Path $SourceDir -Recurse -File | ForEach-Object {
        $basePath = $SourceDir.TrimEnd('\','/')
        $entry = $_.FullName.Substring($basePath.Length + 1).Replace('\','/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $entry) > $null
    }
    $zip.Dispose()
}

$scriptDir      = Split-Path -Parent $MyInvocation.MyCommand.Path
$parentDir      = Split-Path -Parent $scriptDir
$skillName      = Split-Path -Leaf $scriptDir
$releasesDir    = Join-Path $scriptDir "releases_public"
$distPrivateDir = Join-Path $scriptDir "releases_private"

Write-Host "=== Skill Builder: $skillName ===" -ForegroundColor Cyan
Write-Host "Ubicacion: $scriptDir`n" -ForegroundColor Gray

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Read-Host "Version (ej: 1.0.0)"
}
$version = $Version

if ([string]::IsNullOrWhiteSpace($version)) {
    Write-Host "Error: Version requerida" -ForegroundColor Red
    exit 1
}

# ── Verificar archivos necesarios ─────────────────────────────────────────────
Write-Host "Verificando archivos..." -ForegroundColor Yellow
$requiredFiles = @("SKILL.md", "README.md", "LICENSE", ".env.example", "scripts")
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $scriptDir $file
    if (-not (Test-Path $filePath)) {
        Write-Host "Falta: $file" -ForegroundColor Red
        exit 1
    }
}

# El .env debe estar en releases_private/ (gitignoreado, nunca en el repo)
$envFile = Join-Path $distPrivateDir ".env"
if (-not (Test-Path $envFile)) {
    Write-Host "Falta: .env en releases_private/" -ForegroundColor Red
    Write-Host "Crea el fichero con tus credenciales antes de hacer el build." -ForegroundColor Yellow
    exit 1
}

# ── Limpiar ZIPs legacy del directorio padre (versiones antiguas) ─────────────
$oldPrivate = Get-ChildItem -Path $parentDir -Filter "$skillName-v*-private.zip" -File
if ($oldPrivate) {
    Write-Host "Eliminando privados legacy del directorio padre..." -ForegroundColor Yellow
    $oldPrivate | ForEach-Object {
        Remove-Item $_.FullName -Force
        Write-Host "   Eliminado: $($_.Name)" -ForegroundColor Gray
    }
}

# ── Limpiar releases_private anteriores (ZIPs, preserva el .env) ─────────────
if (Test-Path $distPrivateDir) {
    $oldDistPrivate = Get-ChildItem -Path $distPrivateDir -Filter "*.zip"
    if ($oldDistPrivate) {
        Write-Host "Eliminando releases_private anteriores..." -ForegroundColor Yellow
        $oldDistPrivate | ForEach-Object {
            Remove-Item $_.FullName -Force
            Write-Host "   Eliminado: $($_.Name)" -ForegroundColor Gray
        }
    }
} else {
    New-Item -ItemType Directory -Path $distPrivateDir -Force > $null
}

# ── Limpiar releases_public anteriores ───────────────────────────────────────
if (Test-Path $releasesDir) {
    $oldReleases = Get-ChildItem -Path $releasesDir -Filter "*.zip"
    if ($oldReleases) {
        Write-Host "Eliminando releases_public anteriores..." -ForegroundColor Yellow
        $oldReleases | ForEach-Object {
            Remove-Item $_.FullName -Force
            Write-Host "   Eliminado: $($_.Name)" -ForegroundColor Gray
        }
    }
} else {
    New-Item -ItemType Directory -Path $releasesDir -Force > $null
}

# Archivos base incluidos en todos los ZIPs
$baseItems = @(
    (Join-Path $scriptDir "SKILL.md"),
    (Join-Path $scriptDir "README.md"),
    (Join-Path $scriptDir "LICENSE"),
    (Join-Path $scriptDir "scripts")
)
$templatesDir = Join-Path $scriptDir "templates"
if (Test-Path $templatesDir) { $baseItems += $templatesDir }

# ── PUBLIC — sin credenciales, apto para GitHub ───────────────────────────────
Write-Host "`nConstruyendo PUBLICO..." -ForegroundColor Green
$temp = "$env:TEMP\skill-pub-$([System.Random]::new().Next())"
New-Item -ItemType Directory -Path $temp -Force > $null
$publicItems = $baseItems + @((Join-Path $scriptDir ".env.example"))
Copy-Item -Path $publicItems -Destination $temp -Recurse -Force
$publicZip = Join-Path $releasesDir "$skillName-v${version}-public.zip"
New-UnixZip -SourceDir $temp -ZipPath $publicZip
Remove-Item -Path $temp -Recurse -Force
Write-Host "   OK: $($publicZip | Split-Path -Leaf)" -ForegroundColor Green

# ── MASTER — .env completo, todos los clientes ───────────────────────────────
Write-Host "`nConstruyendo MASTER..." -ForegroundColor Magenta
$temp = "$env:TEMP\skill-master-$([System.Random]::new().Next())"
New-Item -ItemType Directory -Path $temp -Force > $null
Copy-Item -Path $baseItems -Destination $temp -Recurse -Force
Copy-Item -Path $envFile -Destination (Join-Path $temp ".env") -Force
$masterZip = Join-Path $distPrivateDir "$skillName-v${version}.zip"
New-UnixZip -SourceDir $temp -ZipPath $masterZip
Remove-Item -Path $temp -Recurse -Force
Write-Host "   OK: $($masterZip | Split-Path -Leaf)  [TODOS los credenciales]" -ForegroundColor Magenta

# ── PER-CLIENT — un ZIP por cliente, solo sus variables ──────────────────────
#
# Lee el .env y agrupa las variables por cliente:
#   Variable {PREFIX}_{CLIENT}_{VARNAME} → grupo CLIENT
#   PREFIX = nombre del skill en mayúsculas (skill-odoo → ODOO)
#
$skillShortName = ($skillName -replace '^skill-', '').ToUpper().Replace('-', '_')
$envPrefix = "${skillShortName}_"
Write-Host "`nDetectando clientes (prefijo env: $envPrefix)..." -ForegroundColor Cyan

$clientGroups = @{}
foreach ($line in (Get-Content $envFile)) {
    $trimmed = $line.Trim()
    if ($trimmed -match '^\s*#' -or [string]::IsNullOrWhiteSpace($trimmed)) { continue }
    if ($trimmed -match '^([A-Z0-9_]+)=(.*)$') {
        $varName = $Matches[1]
        if ($varName.StartsWith($envPrefix)) {
            $clientName = $varName.Substring($envPrefix.Length).Split('_')[0]
            if (-not $clientGroups.ContainsKey($clientName)) {
                $clientGroups[$clientName] = [System.Collections.Generic.List[string]]::new()
            }
            $clientGroups[$clientName].Add($trimmed)
        }
    }
}

if ($clientGroups.Count -eq 0) {
    Write-Host "   Aviso: no se detectaron clientes con prefijo $envPrefix" -ForegroundColor Yellow
    Write-Host "   Asegurate de que las variables siguen el patron: ${envPrefix}{CLIENTE}_{VAR}" -ForegroundColor Yellow
} else {
    foreach ($clientName in ($clientGroups.Keys | Sort-Object)) {
        Write-Host "`nConstruyendo cliente: $clientName..." -ForegroundColor Cyan
        $temp = "$env:TEMP\skill-client-$([System.Random]::new().Next())"
        New-Item -ItemType Directory -Path $temp -Force > $null
        Copy-Item -Path $baseItems -Destination $temp -Recurse -Force

        # .env con solo las variables de este cliente
        $lines = @("# $skillName credentials - $clientName") + $clientGroups[$clientName]
        Set-Content -Path (Join-Path $temp ".env") -Value $lines -Encoding UTF8

        $clientZip = Join-Path $distPrivateDir "$skillName-v${version}_$clientName.zip"
        New-UnixZip -SourceDir $temp -ZipPath $clientZip
        Remove-Item -Path $temp -Recurse -Force
        Write-Host "   OK: $($clientZip | Split-Path -Leaf)" -ForegroundColor Cyan
    }
}

# ── Resumen ───────────────────────────────────────────────────────────────────
Write-Host "`n=== Resumen ===" -ForegroundColor White
Write-Host "Publico  → releases_public/" -ForegroundColor Green
Get-ChildItem -Path $releasesDir -Filter "*.zip" | ForEach-Object { Write-Host "   $($_.Name)" -ForegroundColor Gray }
Write-Host "Privados → releases_private/" -ForegroundColor Magenta
Get-ChildItem -Path $distPrivateDir -Filter "*.zip" | ForEach-Object { Write-Host "   $($_.Name)" -ForegroundColor Gray }
Write-Host "`nHecho!" -ForegroundColor Cyan
