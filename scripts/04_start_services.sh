#!/usr/bin/env bash
# =============================================================================
# FASE 4: Inicio de los servicios Docker
# Uso: bash scripts/04_start_services.sh
# =============================================================================
set -euo pipefail

ODOO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
echo "Directorio del proyecto: $ODOO_DIR"

cd "$ODOO_DIR"

echo "=== [1/4] Verificando archivo de contrasena ==="
if [ ! -f "$ODOO_DIR/odoo_pg_pass" ]; then
    echo "ERROR: No se encontro odoo_pg_pass en $ODOO_DIR"
    echo "Genera uno con: openssl rand -base64 32 | tr -d '=' > $ODOO_DIR/odoo_pg_pass"
    exit 1
fi

PASS=$(cat "$ODOO_DIR/odoo_pg_pass")
if [ "$PASS" = "CAMBIAR_POR_PASSWORD_SEGURO" ]; then
    echo "ERROR: La contrasena en odoo_pg_pass es el valor placeholder."
    echo "Genera una real con: openssl rand -base64 32 | tr -d '=' > $ODOO_DIR/odoo_pg_pass"
    exit 1
fi

echo "=== [2/4] Descargando imagenes Docker ==="
docker compose pull

echo "=== [3/4] Iniciando contenedores ==="
docker compose up -d

echo "=== [4/4] Verificando estado ==="
echo "Esperando 15 segundos para el healthcheck de PostgreSQL..."
sleep 15
docker compose ps

echo ""
echo "Logs recientes de Odoo:"
docker compose logs --tail=30 web

echo ""
echo "=== SERVICIOS INICIADOS ==="
echo ""
echo "Comandos utiles:"
echo "  docker compose logs -f web     # logs en tiempo real de Odoo"
echo "  docker compose logs -f db      # logs de PostgreSQL"
echo "  docker compose ps              # estado de contenedores"
echo "  docker compose restart web     # reiniciar solo Odoo"
echo "  docker compose down            # detener todo"
echo ""
echo "Siguiente paso:"
echo "  bash $ODOO_DIR/scripts/05_setup_cron.sh TU_DOMINIO.com"
