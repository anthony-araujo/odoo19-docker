#!/usr/bin/env bash
# =============================================================================
# FASE 1: Preparacion del servidor Ubuntu 24.04
# Ejecutar como usuario con sudo (NO como root)
# Uso: bash scripts/01_server_setup.sh
# =============================================================================
set -euo pipefail

# Detectar la raiz del proyecto automaticamente (un nivel arriba de scripts/)
ODOO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
echo "Directorio del proyecto: $ODOO_DIR"

echo "=== [1/4] Actualizando el sistema ==="
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git ufw fail2ban

echo "=== [2/4] Instalando Docker Engine ==="
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
    echo ""
    echo "IMPORTANTE: Docker instalado. Cierra la sesion SSH y vuelve a entrar"
    echo "para que el grupo 'docker' tome efecto, luego continua con 02_ssl_setup.sh"
    echo "O ejecuta ahora: newgrp docker"
else
    echo "Docker ya instalado: $(docker --version)"
fi

echo "=== [3/4] Instalando Docker Compose v2 ==="
if ! docker compose version &>/dev/null 2>&1; then
    sudo apt install -y docker-compose-plugin
fi
docker compose version

echo "=== [4/4] Verificando/creando directorios y contrasena ==="
# Crear directorios faltantes (si el repo fue clonado ya existen la mayoria)
mkdir -p "$ODOO_DIR"/{addons,config,sessions,nginx/certs,logs,backups}

PASS_FILE="$ODOO_DIR/odoo_pg_pass"
CURRENT_PASS=""
[ -f "$PASS_FILE" ] && CURRENT_PASS=$(cat "$PASS_FILE" | tr -d '[:space:]')

if [ ! -f "$PASS_FILE" ] || [ "$CURRENT_PASS" = "CAMBIAR_POR_PASSWORD_SEGURO" ] || [ -z "$CURRENT_PASS" ]; then
    openssl rand -base64 32 | tr -d '/+=' > "$PASS_FILE"
    chmod 644 "$PASS_FILE"
    echo "Contrasena generada en: $PASS_FILE"
    echo "Valor: $(cat $PASS_FILE)"
else
    echo "Archivo de contrasena ya existe con valor seguro: $PASS_FILE"
fi

echo ""
echo "=== FASE 1 COMPLETADA ==="
echo "Siguiente paso:"
echo "  bash $ODOO_DIR/scripts/02_ssl_setup.sh TU_DOMINIO.com"
