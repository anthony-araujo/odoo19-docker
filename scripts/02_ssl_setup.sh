#!/usr/bin/env bash
# =============================================================================
# FASE 2: Certificados SSL con Let's Encrypt (Certbot)
# Prerrequisito: DNS del dominio apuntando a la IP de este servidor
# Prerrequisito: puerto 80 accesible desde Internet y Docker DETENIDO
# Uso: bash scripts/02_ssl_setup.sh TU_DOMINIO.com
# =============================================================================
set -euo pipefail

DOMAIN="${1:-}"
ODOO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "$DOMAIN" ]; then
    echo "ERROR: Debes proporcionar el dominio como argumento."
    echo "Uso: bash $ODOO_DIR/scripts/02_ssl_setup.sh TU_DOMINIO.com"
    exit 1
fi

CERT_DIR="$ODOO_DIR/nginx/certs"
NGINX_CONF="$ODOO_DIR/nginx/nginx.conf"

echo "Directorio del proyecto : $ODOO_DIR"
echo "Dominio                 : $DOMAIN"

echo "=== [1/4] Instalando Certbot ==="
sudo apt install -y certbot

echo "=== [2/4] Obteniendo certificado para $DOMAIN ==="
# Modo standalone: no requiere servidor web corriendo en el puerto 80.
# Si Docker ya esta activo, detenerlo antes: docker compose down
sudo certbot certonly --standalone -d "$DOMAIN" \
    --non-interactive --agree-tos --email "admin@${DOMAIN}"

echo "=== [3/4] Copiando certificados a $CERT_DIR ==="
sudo cp "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" "$CERT_DIR/fullchain.pem"
sudo cp "/etc/letsencrypt/live/${DOMAIN}/privkey.pem"   "$CERT_DIR/privkey.pem"
sudo chmod 644 "$CERT_DIR"/*.pem
sudo chown "$USER":"$USER" "$CERT_DIR"/*.pem

echo "=== [4/4] Actualizando dominio en nginx.conf ==="
sed -i "s/TU_DOMINIO\.com/$DOMAIN/g" "$NGINX_CONF"
echo "nginx.conf actualizado con el dominio: $DOMAIN"

echo ""
echo "=== SSL COMPLETADO ==="
echo "Certificados en: $CERT_DIR"
echo "Siguiente paso:"
echo "  bash $ODOO_DIR/scripts/03_firewall_setup.sh"
