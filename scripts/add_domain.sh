#!/usr/bin/env bash
# =============================================================================
# add_domain.sh — Agregar dominio y SSL a una instalacion existente (HTTP)
# Uso: bash scripts/add_domain.sh DOMINIO [EMAIL]
# Ejemplo: bash scripts/add_domain.sh erp.miempresa.com admin@miempresa.com
# =============================================================================
set -euo pipefail

ODOO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOMAIN="${1:-}"
ADMIN_EMAIL="${2:-}"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; NC='\033[0m'
log()   { echo -e "${G}[OK]${NC} $*"; }
warn()  { echo -e "${Y}[!!]${NC} $*"; }
error() { echo -e "${R}[ERROR]${NC} $*" >&2; exit 1; }

[[ -z "$DOMAIN" ]] && error "Uso: bash scripts/add_domain.sh DOMINIO [EMAIL]"
[[ -z "$ADMIN_EMAIL" ]] && ADMIN_EMAIL="admin@${DOMAIN}"

echo ""
echo "  Dominio    : $DOMAIN"
echo "  Email      : $ADMIN_EMAIL"
echo "  Proyecto   : $ODOO_DIR"
echo ""

# --- Verificar que el dominio resuelve a este servidor ---
SERVER_IP=$(hostname -I | awk '{print $1}')
DOMAIN_IP=$(getent hosts "$DOMAIN" | awk '{print $1}' || echo "")
if [[ "$DOMAIN_IP" != "$SERVER_IP" ]]; then
    warn "El dominio $DOMAIN resuelve a $DOMAIN_IP pero este servidor es $SERVER_IP"
    warn "Asegurate de que el registro DNS tipo A apunte a $SERVER_IP"
    read -rp "  ¿Continuar de todas formas? [s/N]: " _ans
    [[ "$_ans" =~ ^[sS] ]] || error "Abortado."
fi

echo "=== [1/4] Instalando Certbot ==="
sudo apt-get install -y -qq certbot

echo "=== [2/4] Deteniendo nginx para liberar puerto 80 ==="
docker compose -f "$ODOO_DIR/docker-compose.yaml" stop nginx

echo "=== [3/4] Obteniendo certificado SSL ==="
sudo certbot certonly --standalone -d "$DOMAIN" \
    --non-interactive --agree-tos --email "$ADMIN_EMAIL"

CERT_DIR="$ODOO_DIR/nginx/certs"
sudo cp "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" "$CERT_DIR/fullchain.pem"
sudo cp "/etc/letsencrypt/live/${DOMAIN}/privkey.pem"   "$CERT_DIR/privkey.pem"
sudo chmod 644 "$CERT_DIR"/*.pem
sudo chown "$USER":"$USER" "$CERT_DIR"/*.pem
log "Certificados copiados a $CERT_DIR"

echo "=== [4/4] Actualizando nginx.conf para HTTPS ==="
cat > "$ODOO_DIR/nginx/nginx.conf" << NGINXEOF
upstream odoo {
    server web:8069;
}
upstream odoo-longpolling {
    server web:8072;
}

server {
    listen 80;
    server_name ${DOMAIN};
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 301 https://\$host\$request_uri; }
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};

    ssl_certificate     /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:!aNULL:!MD5;
    ssl_session_cache   shared:SSL:10m;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;

    proxy_read_timeout    720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout    720s;
    proxy_set_header X-Forwarded-Host  \$host;
    proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP         \$remote_addr;

    location /longpolling/ {
        proxy_pass http://odoo-longpolling;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    location ~* /web/static/ {
        proxy_cache_valid 200 90d;
        proxy_buffering on;
        expires 864000;
        proxy_pass http://odoo;
    }
    location / {
        proxy_pass     http://odoo;
        proxy_redirect off;
    }

    client_max_body_size 100M;
    gzip on;
    gzip_min_length 1024;
    gzip_types text/css text/plain application/json application/javascript image/svg+xml;
}
NGINXEOF

log "nginx.conf actualizado para HTTPS"

# Reiniciar nginx con la nueva configuracion
docker compose -f "$ODOO_DIR/docker-compose.yaml" start nginx
sleep 3
docker compose -f "$ODOO_DIR/docker-compose.yaml" ps nginx

# Agregar cron de renovacion SSL
TMPFILE=$(mktemp)
crontab -l 2>/dev/null > "$TMPFILE" || true
if ! grep -q "certbot renew" "$TMPFILE"; then
    RENEW_CMD="certbot renew --quiet && cp /etc/letsencrypt/live/${DOMAIN}/fullchain.pem ${CERT_DIR}/fullchain.pem && cp /etc/letsencrypt/live/${DOMAIN}/privkey.pem ${CERT_DIR}/privkey.pem && docker exec odoo19_nginx nginx -s reload"
    echo "" >> "$TMPFILE"
    echo "# Renovacion SSL Odoo cada 2 meses" >> "$TMPFILE"
    echo "0 3 1 */2 * $RENEW_CMD" >> "$TMPFILE"
    crontab "$TMPFILE"
    log "Cron de renovacion SSL configurado"
fi
rm -f "$TMPFILE"

echo ""
log "=== DOMINIO Y SSL CONFIGURADOS ==="
echo "  Accede a Odoo en: https://${DOMAIN}"
