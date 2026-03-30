#!/usr/bin/env bash
# =============================================================================
# 02_ssl_setup.sh — Obtener/renovar certificados SSL
# Uso: bash scripts/02_ssl_setup.sh DOMINIO [EMAIL]
# Nota: Para agregar SSL a una instalacion HTTP existente usa add_domain.sh
# =============================================================================
set -euo pipefail

ODOO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOMAIN="${1:-}"
ADMIN_EMAIL="${2:-}"

G='\033[0;32m'; R='\033[0;31m'; NC='\033[0m'
log()   { echo -e "${G}[OK]${NC} $*"; }
error() { echo -e "${R}[ERROR]${NC} $*" >&2; exit 1; }

[[ -z "$DOMAIN" ]] && error "Uso: bash scripts/02_ssl_setup.sh DOMINIO [EMAIL]"
[[ -z "$ADMIN_EMAIL" ]] && ADMIN_EMAIL="admin@${DOMAIN}"

CERT_DIR="$ODOO_DIR/nginx/certs"
echo "Dominio  : $DOMAIN"
echo "Certs en : $CERT_DIR"

echo "=== [1/3] Instalando Certbot ==="
sudo apt-get install -y -qq certbot

echo "=== [2/3] Obteniendo certificado ==="
# Detener nginx para liberar puerto 80
docker compose -f "$ODOO_DIR/docker-compose.yaml" stop nginx 2>/dev/null || true

sudo certbot certonly --standalone -d "$DOMAIN" \
    --non-interactive --agree-tos --email "$ADMIN_EMAIL"

echo "=== [3/3] Copiando certificados ==="
sudo cp "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" "$CERT_DIR/fullchain.pem"
sudo cp "/etc/letsencrypt/live/${DOMAIN}/privkey.pem"   "$CERT_DIR/privkey.pem"
sudo chmod 644 "$CERT_DIR"/*.pem
sudo chown "$USER":"$USER" "$CERT_DIR"/*.pem
log "Certificados en $CERT_DIR"

# Reiniciar nginx
docker compose -f "$ODOO_DIR/docker-compose.yaml" start nginx 2>/dev/null || true

log "=== SSL COMPLETADO para $DOMAIN ==="
