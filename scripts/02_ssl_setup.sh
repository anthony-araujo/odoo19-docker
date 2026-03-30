#!/usr/bin/env bash
# =============================================================================
# FASE 4.2: Obtencion de certificados SSL con Let's Encrypt (Certbot)
# Prerrequisito: el dominio debe apuntar a la IP de este servidor (DNS A record)
# Prerrequisito: el puerto 80 debe estar accesible desde Internet
# Uso: bash 02_ssl_setup.sh TU_DOMINIO.com
# =============================================================================
set -euo pipefail

DOMAIN="${1:-}"

if [ -z "$DOMAIN" ]; then
    echo "ERROR: Debes proporcionar el dominio como argumento."
    echo "Uso: bash 02_ssl_setup.sh TU_DOMINIO.com"
    exit 1
fi

CERT_DIR="/opt/odoo/nginx/certs"
NGINX_CONF="/opt/odoo/nginx/nginx.conf"

echo "=== [1/4] Instalando Certbot ==="
sudo apt install -y certbot

echo "=== [2/4] Obteniendo certificado para $DOMAIN ==="
# Modo standalone: detiene cualquier proceso en el puerto 80 temporalmente.
# Si Docker ya esta corriendo, usa: --webroot -w /var/www/certbot
sudo certbot certonly --standalone -d "$DOMAIN" \
    --non-interactive --agree-tos --email admin@"$DOMAIN"

echo "=== [3/4] Copiando certificados a /opt/odoo/nginx/certs/ ==="
sudo cp /etc/letsencrypt/live/"$DOMAIN"/fullchain.pem "$CERT_DIR"/fullchain.pem
sudo cp /etc/letsencrypt/live/"$DOMAIN"/privkey.pem   "$CERT_DIR"/privkey.pem
sudo chmod 644 "$CERT_DIR"/*.pem
sudo chown "$USER":"$USER" "$CERT_DIR"/*.pem

echo "=== [4/4] Actualizando dominio en nginx.conf ==="
sed -i "s/TU_DOMINIO.com/$DOMAIN/g" "$NGINX_CONF"
echo "Nginx configurado para el dominio: $DOMAIN"

echo ""
echo "=== SSL COMPLETADO ==="
echo "Certificados en: $CERT_DIR"
echo "Siguiente paso: ejecutar 03_firewall_setup.sh"
