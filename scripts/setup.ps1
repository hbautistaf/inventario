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
# 1. Comprobacion de Node.js y npm
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[1/5] Verificando Node.js y npm..." -ForegroundColor Yellow

try {
    $nodeVersion = node -v
    Write-Host "[OK] Node.js detectado: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Node.js no esta instalado o no se encuentra en el PATH." -ForegroundColor Red
    Write-Host "  Descargalo e instalalo desde: https://nodejs.org/" -ForegroundColor Yellow
    exit 1
}

try {
    $npmVersion = npm -v
    Write-Host "[OK] npm detectado: $npmVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] npm no esta disponible." -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------------------------
# 2. Instalacion de Dependencias de Node
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[2/5] Instalando dependencias de Node.js (npm install)..." -ForegroundColor Yellow
& npm install
Write-Host "[OK] Dependencias instaladas correctamente." -ForegroundColor Green

# ------------------------------------------------------------------------------
# 3. Preparacion de Variables de Entorno (.env.local)
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[3/5] Configurando variables de entorno (.env.local)..." -ForegroundColor Yellow

$envLocalPath = Join-Path $PSScriptRoot "..\.env.local"
$envExamplePath = Join-Path $PSScriptRoot "..\.env.example"

if (-not (Test-Path $envLocalPath)) {
    if (Test-Path $envExamplePath) {
        Copy-Item $envExamplePath $envLocalPath
        Write-Host "[OK] Archivo .env.local creado a partir de .env.example." -ForegroundColor Green
    } else {
        $defaultEnvLines = @(
            "NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321",
            "NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyZWZlcmVuY2UiOiJpbnZlbnRhcmlvLXVuaXZlcnNhbCIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzI3OTkyMDAwLCJleHAiOjIwNDMzNTIwMDB9.EXAMPLE_KEY",
            "SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyZWZlcmVuY2UiOiJpbnZlbnRhcmlvLXVuaXZlcnNhbCIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE3Mjc5OTIwMDAsImV4cCI6MjA0MzM1MjAwMH0.EXAMPLE_KEY",
            "DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres"
        )
        Set-Content -Path $envLocalPath -Value $defaultEnvLines
        Write-Host "[OK] Archivo .env.local generado con valores predeterminados." -ForegroundColor Green
    }
} else {
    Write-Host "[INFO] Archivo .env.local ya existe. Se conserva la configuracion." -ForegroundColor Cyan
}

# ------------------------------------------------------------------------------
# 4. Verificacion de Docker Desktop en Windows
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[4/5] Verificando Docker Desktop para Supabase Local..." -ForegroundColor Yellow
$dockerReady = $false

try {
    $null = Get-Command docker -ErrorAction Stop
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Docker Desktop esta instalado y en ejecucion." -ForegroundColor Green
        $dockerReady = $true
    } else {
        Write-Host "[WARN] Docker CLI esta instalado pero el demonio no esta respondiendo." -ForegroundColor Yellow
        Write-Host "  Abre la aplicacion Docker Desktop en Windows y espera a que inicie el motor." -ForegroundColor Yellow
    }
} catch {
    Write-Host "[ERROR] No se encontro Docker en el sistema." -ForegroundColor Red
    Write-Host "  Para usar Supabase local en Windows, instala Docker Desktop con soporte WSL2:" -ForegroundColor Yellow
    Write-Host "  https://docs.docker.com/desktop/setup/install/windows-install/" -ForegroundColor Cyan
}

# ------------------------------------------------------------------------------
# 5. Opciones de Arranque de Supabase
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[5/5] Estado de Base de Datos..." -ForegroundColor Yellow

if ($dockerReady) {
    $response = Read-Host "Deseas iniciar Supabase local y aplicar migraciones ahora? (s/N)"
    if ($response -match "^[sSyY]$") {
        Write-Host "Iniciando Supabase Local..." -ForegroundColor Cyan
        & npx supabase start
        Write-Host "Aplicando migracion canonica limpia..." -ForegroundColor Cyan
        & npx supabase db reset
        Write-Host "[OK] Supabase iniciado correctamente." -ForegroundColor Green
        Write-Host "  Studio: http://127.0.0.1:54323" -ForegroundColor Cyan
        Write-Host "  API:    http://127.0.0.1:54321" -ForegroundColor Cyan
    }
} else {
    Write-Host "Una vez que tengas Docker Desktop activo, ejecuta en PowerShell:" -ForegroundColor Yellow
    Write-Host "  npm run db:start" -ForegroundColor Cyan
    Write-Host "  npm run db:reset" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "   [OK] Configuracion completada con exito.                           " -ForegroundColor Green
Write-Host "   Para iniciar la aplicacion Next.js ejecuta: npm run dev            " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
