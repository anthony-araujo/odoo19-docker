#!/usr/bin/env bash
# =============================================================================
# FASE 7 y 8: Configuracion de tareas programadas (crontab)
# - Backup diario a las 2:00 AM
# - Renovacion automatica de SSL cada 2 meses
# Uso: bash 05_setup_cron.sh TU_DOMINIO.com
# =============================================================================
set -euo pipefail

DOMAIN="${1:-}"
ODOO_DIR="/opt/odoo"

if [ -z "$DOMAIN" ]; then
    echo "ERROR: Debes proporcionar el dominio como argumento."
    echo "Uso: bash 05_setup_cron.sh TU_DOMINIO.com"
    exit 1
fi

echo "=== [1/3] Preparando script de backup ==="
chmod +x "$ODOO_DIR/backups/backup.sh"

# --- Construir nuevo crontab ---
TMPFILE=$(mktemp)

# Preservar crontab existente (si hay)
crontab -l 2>/dev/null > "$TMPFILE" || true

# Agregar entrada de backup si no existe
if ! grep -q "backup.sh" "$TMPFILE"; then
    echo "# Odoo backup diario a las 2:00 AM" >> "$TMPFILE"
    echo "0 2 * * * $ODOO_DIR/backups/backup.sh >> $ODOO_DIR/logs/backup.log 2>&1" >> "$TMPFILE"
    echo "Entrada de backup agregada al crontab."
else
    echo "La entrada de backup ya existe en crontab, no se duplica."
fi

# Agregar renovacion de SSL si no existe
RENEW_CMD="certbot renew --quiet && cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $ODOO_DIR/nginx/certs/fullchain.pem && cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $ODOO_DIR/nginx/certs/privkey.pem && docker exec odoo19_nginx nginx -s reload"
if ! grep -q "certbot renew" "$TMPFILE"; then
    echo "" >> "$TMPFILE"
    echo "# Renovacion automatica de certificados SSL (cada 2 meses el dia 1 a las 3:00 AM)" >> "$TMPFILE"
    echo "0 3 1 */2 * $RENEW_CMD" >> "$TMPFILE"
    echo "Entrada de renovacion SSL agregada al crontab."
else
    echo "La entrada de renovacion SSL ya existe en crontab, no se duplica."
fi

echo "=== [2/3] Instalando crontab ==="
crontab "$TMPFILE"
rm -f "$TMPFILE"

echo "=== [3/3] Crontab actual ==="
crontab -l

echo ""
echo "=== TAREAS PROGRAMADAS CONFIGURADAS ==="
echo "  Backup     : diario a las 02:00 AM -> $ODOO_DIR/backups/"
echo "  Renovar SSL: cada 2 meses el dia 1 a las 03:00 AM"
