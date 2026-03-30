#!/usr/bin/env bash
# =============================================================================
# 05_setup_cron.sh — Configurar backups y renovacion SSL automatica
# Uso: bash scripts/05_setup_cron.sh [DOMINIO]
# =============================================================================
set -euo pipefail

ODOO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOMAIN="${1:-}"
G='\033[0;32m'; NC='\033[0m'
log() { echo -e "${G}[OK]${NC} $*"; }

chmod +x "$ODOO_DIR/backups/backup.sh"

TMPFILE=$(mktemp)
crontab -l 2>/dev/null > "$TMPFILE" || true

if ! grep -q "backup.sh" "$TMPFILE"; then
    echo "# Odoo 19 — Backup diario 02:00 AM" >> "$TMPFILE"
    echo "0 2 * * * $ODOO_DIR/backups/backup.sh >> $ODOO_DIR/logs/backup.log 2>&1" >> "$TMPFILE"
    log "Cron de backup: diario 02:00 AM"
else
    log "Cron de backup ya configurado"
fi

if [[ -n "$DOMAIN" ]] && ! grep -q "certbot renew" "$TMPFILE"; then
    CERT_DIR="$ODOO_DIR/nginx/certs"
    RENEW="certbot renew --quiet && cp /etc/letsencrypt/live/${DOMAIN}/fullchain.pem ${CERT_DIR}/fullchain.pem && cp /etc/letsencrypt/live/${DOMAIN}/privkey.pem ${CERT_DIR}/privkey.pem && docker exec odoo19_nginx nginx -s reload"
    echo "" >> "$TMPFILE"
    echo "# Odoo 19 — Renovacion SSL cada 2 meses" >> "$TMPFILE"
    echo "0 3 1 */2 * $RENEW" >> "$TMPFILE"
    log "Cron de renovacion SSL: cada 2 meses"
fi

crontab "$TMPFILE"
rm -f "$TMPFILE"

log "Crontab configurado:"
crontab -l
