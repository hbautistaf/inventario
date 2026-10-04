#!/usr/bin/env bash
# ==============================================================================
# Inventario Universal - Script Universal de Setup (Linux & macOS)
# Compatible con: Ubuntu, Debian, Fedora, RHEL, Arch, Manjaro, Alpine y macOS
# ==============================================================================

set -euo pipefail

# Colores de salida
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}       Inventario Universal - Setup Universal (Linux / macOS)         ${NC}"
echo -e "${BLUE}======================================================================${NC}"

OS_NAME="$(uname -s)"

# ------------------------------------------------------------------------------
# 1. Comprobación de Node.js y npm
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[1/5] Verificando Node.js y npm...${NC}"

if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✓ Node.js detectado: ${NODE_VERSION}${NC}"
else
    echo -e "${RED}✗ Node.js no está instalado.${NC}"
    if [ "$OS_NAME" = "Darwin" ]; then
        echo -e "  En macOS puedes instalarlo con Homebrew: ${BLUE}brew install node${NC}"
    else
        echo -e "  Por favor instala Node.js (v18 o superior) usando el gestor de paquetes de tu distribución o nvm."
    fi
    exit 1
fi

if command -v npm >/dev/null 2>&1; then
    NPM_VERSION=$(npm -v)
    echo -e "${GREEN}✓ npm detectado: ${NPM_VERSION}${NC}"
else
    echo -e "${RED}✗ npm no está instalado.${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Instalación de Dependencias de Node
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[2/5] Instalando dependencias del proyecto (npm install)...${NC}"
npm install
echo -e "${GREEN}✓ Dependencias de Node.js listas.${NC}"

# ------------------------------------------------------------------------------
# 3. Preparación de Variables de Entorno (.env.local)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[3/5] Configurando variables de entorno (.env.local)...${NC}"
if [ ! -f ".env.local" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env.local
        echo -e "${GREEN}✓ Archivo .env.local creado a partir de .env.example.${NC}"
    else
        cat << 'EOF' > .env.local
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyZWZlcmVuY2UiOiJpbnZlbnRhcmlvLXVuaXZlcnNhbCIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzI3OTkyMDAwLCJleHAiOjIwNDMzNTIwMDB9.EXAMPLE_KEY
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyZWZlcmVuY2UiOiJpbnZlbnRhcmlvLXVuaXZlcnNhbCIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE3Mjc5OTIwMDAsImV4cCI6MjA0MzM1MjAwMH0.EXAMPLE_KEY
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres
EOF
        echo -e "${GREEN}✓ Archivo .env.local generado con valores base.${NC}"
    fi
else
    echo -e "${BLUE}ℹ Archivo .env.local existente encontrado. Se preserva.${NC}"
fi

# ------------------------------------------------------------------------------
# 4. Verificación del Motor de Contenedores (Docker / Podman)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[4/5] Verificando Docker / Podman para Supabase Local...${NC}"
CONTAINER_ENGINE_READY=false

if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker instalado y en ejecución.${NC}"
        CONTAINER_ENGINE_READY=true
    else
        echo -e "${YELLOW}⚠ Docker está instalado pero el demonio no está respondiendo.${NC}"
        if [ "$OS_NAME" = "Darwin" ]; then
            echo -e "  Asegúrate de que la aplicación ${BOLD}Docker Desktop${NC} esté abierta."
        else
            echo -e "  Inicia el servicio con: ${BLUE}sudo systemctl start docker${NC}"
        fi
    fi
elif command -v podman >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Podman detectado.${NC}"
    CONTAINER_ENGINE_READY=true
else
    echo -e "${RED}✗ No se encontró Docker ni Podman en tu sistema.${NC}"
    echo -e "${YELLOW}Supabase Local requiere Docker para correr PostgreSQL, Auth y Studio.${NC}"

    if [ "$OS_NAME" = "Darwin" ]; then
        echo -e "\nEn macOS puedes instalar Docker Desktop con Homebrew:"
        echo -e "  ${BLUE}brew install --cask docker${NC}"
    elif [ -f "/etc/os-release" ]; then
        . /etc/os-release
        case "${ID:-linux}" in
            ubuntu|debian)
                echo -e "\nEn Debian/Ubuntu puedes instalar Docker con:"
                echo -e "  ${BLUE}sudo apt-get update && sudo apt-get install -y docker.io${NC}"
                echo -e "  ${BLUE}sudo systemctl enable --now docker${NC}"
                echo -e "  ${BLUE}sudo usermod -aG docker \$USER${NC}"
                ;;
            fedora|rhel|centos)
                echo -e "\nEn Fedora/RHEL puedes instalar Docker con:"
                echo -e "  ${BLUE}sudo dnf install -y moby-engine${NC}"
                echo -e "  ${BLUE}sudo systemctl enable --now docker${NC}"
                echo -e "  ${BLUE}sudo usermod -aG docker \$USER${NC}"
                ;;
            arch|manjaro)
                echo -e "\nEn Arch/Manjaro puedes instalar Docker con:"
                echo -e "  ${BLUE}sudo pacman -S docker docker-compose${NC}"
                echo -e "  ${BLUE}sudo systemctl enable --now docker${NC}"
                echo -e "  ${BLUE}sudo usermod -aG docker \$USER${NC}"
                ;;
            *)
                echo -e "Consulta las instrucciones de instalación de Docker para ${NAME:-tu distribución}."
                ;;
        esac
    fi
fi

# ------------------------------------------------------------------------------
# 5. Opciones de Arranque de Supabase Local
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[5/5] Estado de Base de Datos...${NC}"

if [ "$CONTAINER_ENGINE_READY" = true ]; then
    read -p "¿Deseas iniciar Supabase local y aplicar migraciones ahora? [s/N]: " -r RESP || RESP="n"
    if [[ "$RESP" =~ ^[sSyY]$ ]]; then
        echo -e "${BLUE}Iniciando Supabase Local (npx supabase start)...${NC}"
        npx supabase start
        echo -e "${BLUE}Aplicando migración canónica limpia (npx supabase db reset)...${NC}"
        npx supabase db reset
        echo -e "${GREEN}✓ Supabase Local iniciado y listo.${NC}"
        echo -e "  Studio: ${BLUE}http://127.0.0.1:54323${NC}"
        echo -e "  API:    ${BLUE}http://127.0.0.1:54321${NC}"
    fi
else
    echo -e "${YELLOW}Una vez que Docker esté activo, puedes iniciar la base de datos con:${NC}"
    echo -e "  ${BLUE}npm run db:start${NC}"
    echo -e "  ${BLUE}npm run db:reset${NC}"
fi

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}   ✓ Configuración completada. Para iniciar la aplicación web:       ${NC}"
echo -e "     ${BOLD}npm run dev${NC}  ->  http://localhost:3000"
echo -e "${GREEN}======================================================================${NC}\n"
