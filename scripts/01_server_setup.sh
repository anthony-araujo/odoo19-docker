#!/usr/bin/env bash
# =============================================================================
# 01_server_setup.sh — Instalar Docker y generar contrasena de BD
# Uso: bash scripts/01_server_setup.sh
# Nota: Este script es llamado automaticamente por install.sh
# =============================================================================
set -euo pipefail

ODOO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; NC='\033[0m'
log()   { echo -e "${G}[OK]${NC} $*"; }
warn()  { echo -e "${Y}[!!]${NC} $*"; }
error() { echo -e "${R}[ERROR]${NC} $*" >&2; exit 1; }

echo "Directorio del proyecto: $ODOO_DIR"

echo "=== [1/3] Actualizando sistema e instalando dependencias ==="
sudo apt-get update -qq
sudo apt-get install -y -qq curl wget git ufw fail2ban ca-certificates gnupg
log "Dependencias instaladas"

echo "=== [2/3] Instalando Docker Engine ==="
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
    log "Docker instalado: $(docker --version)"
    warn "Cierra la sesion SSH y vuelve a entrar (o ejecuta: newgrp docker)"
else
    log "Docker ya instalado: $(docker --version)"
fi

if ! docker compose version &>/dev/null 2>&1; then
    sudo apt-get install -y -qq docker-compose-plugin
fi
log "Docker Compose: $(docker compose version --short)"

echo "=== [3/3] Generando contrasena segura ==="
mkdir -p "$ODOO_DIR"/{addons,config,sessions,nginx/certs,logs,backups}

PASS_FILE="$ODOO_DIR/odoo_pg_pass"
CURRENT_PASS=""
[[ -f "$PASS_FILE" ]] && CURRENT_PASS=$(tr -d '[:space:]' < "$PASS_FILE")

if [[ ! -f "$PASS_FILE" ]] || [[ -z "$CURRENT_PASS" ]] || [[ "$CURRENT_PASS" == "CAMBIAR_POR_PASSWORD_SEGURO" ]]; then
    openssl rand -hex 24 > "$PASS_FILE"
    log "Contrasena generada: $PASS_FILE"
else
    log "Contrasena existente conservada: $PASS_FILE"
fi

# IMPORTANTE: 644 es requerido para que Docker secrets pueda leerlo
chmod 644 "$PASS_FILE"
log "Permisos de odoo_pg_pass: 644"

echo ""
log "=== FASE 1 COMPLETADA ==="
echo "Siguiente: bash install.sh --domain TU_DOMINIO.com"
echo "       o : bash install.sh --no-domain"
