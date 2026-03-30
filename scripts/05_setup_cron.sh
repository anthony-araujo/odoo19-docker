#!/usr/bin/env bash
# =============================================================================
# FASE 5: Tareas programadas (crontab)
# - Backup diario a las 2:00 AM
# - Renovacion automatica de SSL cada 2 meses
# Uso: bash scripts/05_setup_cron.sh TU_DOMINIO.com
# =============================================================================
set -euo pipefail

DOMAIN="${1:-}"
ODOO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "$DOMAIN" ]; then
    echo "ERROR: Debes proporcionar el dominio como argumento."
    echo "Uso: bash $ODOO_DIR/scripts/05_setup_cron.sh TU_DOMINIO.com"
    exit 1
fi

echo "Directorio del proyecto: $ODOO_DIR"

echo "=== [1/3] Dando permisos de ejecucion al script de backup ==="
chmod +x "$ODOO_DIR/backups/backup.sh"

TMPFILE=$(mktemp)
crontab -l 2>/dev/null > "$TMPFILE" || true

echo "=== [2/3] Agregando tareas al crontab ==="

if ! grep -q "backup.sh" "$TMPFILE"; then
    echo "# Odoo 19 - Backup diario a las 2:00 AM" >> "$TMPFILE"
    echo "0 2 * * * $ODOO_DIR/backups/backup.sh >> $ODOO_DIR/logs/backup.log 2>&1" >> "$TMPFILE"
    echo "Entrada de backup agregada."
else
    echo "Entrada de backup ya existe, omitiendo."
fi

RENEW_CMD="certbot renew --quiet && cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $ODOO_DIR/nginx/certs/fullchain.pem && cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $ODOO_DIR/nginx/certs/privkey.pem && docker exec odoo19_nginx nginx -s reload"
if ! grep -q "certbot renew" "$TMPFILE"; then
    echo "" >> "$TMPFILE"
    echo "# Odoo 19 - Renovacion SSL cada 2 meses el dia 1 a las 3:00 AM" >> "$TMPFILE"
    echo "0 3 1 */2 * $RENEW_CMD" >> "$TMPFILE"
    echo "Entrada de renovacion SSL agregada."
else
    echo "Entrada de renovacion SSL ya existe, omitiendo."
fi

crontab "$TMPFILE"
rm -f "$TMPFILE"

echo "=== [3/3] Crontab configurado ==="
crontab -l

echo ""
echo "=== TAREAS PROGRAMADAS LISTAS ==="
echo "  Backup     : diario 02:00 AM -> $ODOO_DIR/backups/"
echo "  Renovar SSL: cada 2 meses dia 1 a las 03:00 AM"
echo ""
echo "=== INSTALACION COMPLETADA ==="
echo "Accede a Odoo en: https://$DOMAIN"
