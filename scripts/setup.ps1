# ==============================================================================
# Inventario Universal - Script de Setup para Windows (PowerShell)
# Compatible con: Windows 10 y Windows 11 (PowerShell 5.1 / PowerShell 7+)
# ==============================================================================

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       Inventario Universal - Setup Local para Windows                " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 1. Comprobación de Node.js y npm
# ------------------------------------------------------------------------------
Write-Host "`n[1/5] Verificando Node.js y npm..." -ForegroundColor Yellow

try {
    $nodeVersion = node -v
    Write-Host "✓ Node.js detectado: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Node.js no está instalado o no se encuentra en el PATH." -ForegroundColor Red
    Write-Host "  Descárgalo e instálalo desde: https://nodejs.org/" -ForegroundColor Yellow
    exit 1
}

try {
    $npmVersion = npm -v
    Write-Host "✓ npm detectado: $npmVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ npm no está disponible." -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------------------------
# 2. Instalación de Dependencias de Node
# ------------------------------------------------------------------------------
Write-Host "`n[2/5] Instalando dependencias de Node.js (npm install)..." -ForegroundColor Yellow
& npm install
Write-Host "✓ Dependencias instaladas correctamente." -ForegroundColor Green

# ------------------------------------------------------------------------------
# 3. Preparación de Variables de Entorno (.env.local)
# ------------------------------------------------------------------------------
Write-Host "`n[3/5] Configurando variables de entorno (.env.local)..." -ForegroundColor Yellow

$envLocalPath = Join-Path $PSScriptRoot "..\.env.local"
$envExamplePath = Join-Path $PSScriptRoot "..\.env.example"

if (-not (Test-Path $envLocalPath)) {
    if (Test-Path $envExamplePath) {
        Copy-Item $envExamplePath $envLocalPath
        Write-Host "✓ Archivo .env.local creado a partir de .env.example." -ForegroundColor Green
    } else {
        $defaultEnv = @"
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyZWZlcmVuY2UiOiJpbnZlbnRhcmlvLXVuaXZlcnNhbCIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzI3OTkyMDAwLCJleHAiOjIwNDMzNTIwMDB9.EXAMPLE_KEY
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyZWZlcmVuY2UiOiJpbnZlbnRhcmlvLXVuaXZlcnNhbCIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE3Mjc5OTIwMDAsImV4cCI6MjA0MzM1MjAwMH0.EXAMPLE_KEY
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres
"@
        Set-Content -Path $envLocalPath -Value $defaultEnv
        Write-Host "✓ Archivo .env.local generado con valores predeterminados." -ForegroundColor Green
    }
} else {
    Write-Host "ℹ Archivo .env.local ya existe. Se conserva la configuración." -ForegroundColor Cyan
}

# ------------------------------------------------------------------------------
# 4. Verificación de Docker Desktop en Windows
# ------------------------------------------------------------------------------
Write-Host "`n[4/5] Verificando Docker Desktop para Supabase Local..." -ForegroundColor Yellow
$dockerReady = $false

try {
    $null = Get-Command docker -ErrorAction Stop
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Docker Desktop está instalado y en ejecución." -ForegroundColor Green
        $dockerReady = $true
    } else {
        Write-Host "⚠ Docker CLI está instalado pero el demonio no está respondiendo." -ForegroundColor Yellow
        Write-Host "  Abre la aplicación Docker Desktop en Windows y espera a que inicie el motor." -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ No se encontró Docker en el sistema." -ForegroundColor Red
    Write-Host "  Para usar Supabase local en Windows, instala Docker Desktop con soporte WSL2:" -ForegroundColor Yellow
    Write-Host "  https://docs.docker.com/desktop/setup/install/windows-install/" -ForegroundColor Cyan
}

# ------------------------------------------------------------------------------
# 5. Opciones de Arranque de Supabase
# ------------------------------------------------------------------------------
Write-Host "`n[5/5] Estado de Base de Datos..." -ForegroundColor Yellow

if ($dockerReady) {
    $response = Read-Host "¿Deseas iniciar Supabase local y aplicar migraciones ahora? (s/N)"
    if ($response -match "^[sSyY]$") {
        Write-Host "Iniciando Supabase Local..." -ForegroundColor Cyan
        & npx supabase start
        Write-Host "Aplicando migración canónica limpia..." -ForegroundColor Cyan
        & npx supabase db reset
        Write-Host "✓ Supabase iniciado correctamente." -ForegroundColor Green
        Write-Host "  Studio: http://127.0.0.1:54323" -ForegroundColor Cyan
        Write-Host "  API:    http://127.0.0.1:54321" -ForegroundColor Cyan
    }
} else {
    Write-Host "Una vez que tengas Docker Desktop activo, ejecuta en PowerShell:" -ForegroundColor Yellow
    Write-Host "  npm run db:start" -ForegroundColor Cyan
    Write-Host "  npm run db:reset" -ForegroundColor Cyan
}

Write-Host "`n======================================================================" -ForegroundColor Green
Write-Host "   ✓ Configuración completada con éxito.                              " -ForegroundColor Green
Write-Host "   Para iniciar la aplicación Next.js ejecuta: npm run dev            " -ForegroundColor Green
Write-Host "======================================================================`n" -ForegroundColor Green
