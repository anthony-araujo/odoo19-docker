#!/usr/bin/env bash
# =============================================================================
# FASE 6: Inicio de los servicios Docker
# Uso: bash 04_start_services.sh
# =============================================================================
set -euo pipefail

ODOO_DIR="/opt/odoo"

cd "$ODOO_DIR"

echo "=== [1/4] Verificando archivo de contrasena ==="
if [ ! -f "$ODOO_DIR/odoo_pg_pass" ]; then
    echo "ERROR: No se encontro odoo_pg_pass en $ODOO_DIR"
    echo "Ejecuta primero: 01_server_setup.sh"
    exit 1
fi

PASS=$(cat "$ODOO_DIR/odoo_pg_pass")
if [ "$PASS" = "CAMBIAR_POR_PASSWORD_SEGURO" ]; then
    echo "ERROR: La contrasena en odoo_pg_pass es el valor por defecto."
    echo "Genera una real con: openssl rand -base64 32 | tr -d '=' > $ODOO_DIR/odoo_pg_pass"
    exit 1
fi

echo "=== [2/4] Descargando imagenes Docker ==="
docker compose pull

echo "=== [3/4] Iniciando contenedores ==="
docker compose up -d

echo "=== [4/4] Verificando estado de los contenedores ==="
echo "Esperando 15 segundos para que PostgreSQL pase el healthcheck..."
sleep 15
docker compose ps

echo ""
echo "Logs recientes de Odoo:"
docker compose logs --tail=30 web

echo ""
echo "=== SERVICIOS INICIADOS ==="
echo "Accede a Odoo en: https://TU_DOMINIO.com"
echo "  (reemplaza TU_DOMINIO.com por el dominio real)"
echo ""
echo "Comandos utiles:"
echo "  docker compose logs -f web        # seguir logs de Odoo"
echo "  docker compose logs -f db         # seguir logs de PostgreSQL"
echo "  docker compose ps                 # estado de los contenedores"
echo "  docker compose restart web        # reiniciar solo Odoo"
echo "  docker compose down               # detener todos los servicios"
