#!/usr/bin/env bash
# =============================================================================
# 04_start_services.sh — Iniciar o reiniciar los servicios Docker
# Uso: bash scripts/04_start_services.sh [--clean]
#   --clean : elimina volumenes antes de iniciar (BORRA DATOS)
# =============================================================================
set -euo pipefail

ODOO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLEAN=false
G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; NC='\033[0m'
log()   { echo -e "${G}[OK]${NC} $*"; }
warn()  { echo -e "${Y}[!!]${NC} $*"; }
error() { echo -e "${R}[ERROR]${NC} $*" >&2; exit 1; }

[[ "${1:-}" == "--clean" ]] && CLEAN=true

cd "$ODOO_DIR"

# Verificar contrasena
PASS_FILE="$ODOO_DIR/odoo_pg_pass"
[[ ! -f "$PASS_FILE" ]] && error "No se encontro $PASS_FILE. Ejecuta primero: bash scripts/01_server_setup.sh"
PASS=$(tr -d '[:space:]' < "$PASS_FILE")
[[ "$PASS" == "CAMBIAR_POR_PASSWORD_SEGURO" ]] && error "La contrasena es el placeholder. Ejecuta: bash scripts/01_server_setup.sh"
[[ -z "$PASS" ]] && error "El archivo odoo_pg_pass esta vacio."
chmod 644 "$PASS_FILE"

echo "=== [1/3] Deteniendo servicios ==="
if [[ "$CLEAN" == "true" ]]; then
    warn "Modo --clean: se eliminaran los volumenes (DATOS BORRADOS)"
    read -rp "  ¿Confirmas? [s/N]: " _ans
    [[ "$_ans" =~ ^[sS] ]] || error "Abortado."
    docker compose down -v
    log "Contenedores y volumenes eliminados"
else
    docker compose down
    log "Contenedores detenidos"
fi

echo "=== [2/3] Iniciando servicios ==="
docker compose pull --quiet
docker compose up -d

echo "=== [3/3] Verificando estado (espera hasta 90s) ==="
ATTEMPTS=0
while [[ $ATTEMPTS -lt 18 ]]; do
    sleep 5; ATTEMPTS=$((ATTEMPTS + 1))
    DB_OK=$(docker compose ps --format "{{.Service}} {{.Status}}" | grep "^db " | grep -c "healthy" || true)
    WEB_OK=$(docker compose ps --format "{{.Service}} {{.Status}}" | grep "^web " | grep -v "Restarting\|Exit" | grep -c "Up" || true)
    echo -ne "  $((ATTEMPTS*5))s — DB: $([[ $DB_OK -gt 0 ]] && echo OK || echo wait) | Web: $([[ $WEB_OK -gt 0 ]] && echo OK || echo wait)\r"
    [[ $DB_OK -gt 0 && $WEB_OK -gt 0 ]] && { echo ""; log "Servicios listos"; break; }
done
echo ""

docker compose ps

WEB_FAIL=$(docker compose ps --format "{{.Service}} {{.Status}}" | grep "^web " | grep -c "Restarting\|Exit" || true)
if [[ $WEB_FAIL -gt 0 ]]; then
    warn "Odoo no arranco correctamente. Logs:"
    docker compose logs --tail=30 web
    error "Revisa los logs: docker compose logs web"
fi

SERVER_IP=$(hostname -I | awk '{print $1}')
log "=== SERVICIOS CORRIENDO ==="
echo "  Accede en: http://${SERVER_IP} (o https://TU_DOMINIO si tienes SSL)"
