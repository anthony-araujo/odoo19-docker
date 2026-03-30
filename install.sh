#!/usr/bin/env bash
# =============================================================================
# install.sh — Instalacion de Odoo 19 en Ubuntu 24.04 con Docker
#
# Uso:
#   bash install.sh                          # modo interactivo (recomendado)
#   bash install.sh --domain erp.miweb.com   # con dominio (HTTPS automatico)
#   bash install.sh --no-domain              # sin dominio (HTTP, para pruebas)
#
# Ejecutar como usuario con sudo, NO como root.
# =============================================================================
set -euo pipefail

ODOO_DIR="$(cd "$(dirname "$0")" && pwd)"
DOMAIN=""
HAS_DOMAIN=false
ADMIN_EMAIL=""
FRESH_INSTALL=true

# --- Colores ---
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'; NC='\033[0m'
log()     { echo -e "${G}[OK]${NC} $*"; }
warn()    { echo -e "${Y}[!!]${NC} $*"; }
error()   { echo -e "${R}[ERROR]${NC} $*" >&2; exit 1; }
section() { echo -e "\n${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; \
            echo -e "${B}  $*${NC}"; \
            echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

# --- Parseo de argumentos ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain)    DOMAIN="${2:-}"; HAS_DOMAIN=true;  shift 2 ;;
        --no-domain) HAS_DOMAIN=false;                  shift   ;;
        --email)     ADMIN_EMAIL="${2:-}";               shift 2 ;;
        --help|-h)
            echo "Uso: bash install.sh [--domain DOMINIO] [--email EMAIL] [--no-domain]"
            exit 0 ;;
        *) error "Argumento desconocido: $1. Usa --help para ver opciones." ;;
    esac
done

# --- Banner ---
echo ""
echo -e "${B}╔══════════════════════════════════════════════╗${NC}"
echo -e "${B}║     Odoo 19 — Instalacion en Ubuntu 24.04   ║${NC}"
echo -e "${B}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo "  Directorio del proyecto : $ODOO_DIR"
echo "  Usuario                 : $USER"
echo ""

# --- Modo interactivo si no se paso argumento de dominio ---
if [[ $# -eq 0 ]] && [[ "$HAS_DOMAIN" == "false" ]] && [[ -z "$DOMAIN" ]]; then
    echo "¿Tienes un dominio ya configurado apuntando a este servidor (registro DNS tipo A)?"
    read -rp "  [s = si tengo dominio / N = instalar sin dominio por ahora]: " _ans
    if [[ "$_ans" =~ ^[sS] ]]; then
        HAS_DOMAIN=true
        read -rp "  Ingresa el dominio (ej: erp.miempresa.com): " DOMAIN
        if [[ -z "$ADMIN_EMAIL" ]]; then
            read -rp "  Email para Let's Encrypt (ej: admin@miempresa.com): " ADMIN_EMAIL
        fi
    else
        warn "Instalando en modo HTTP. Podras agregar SSL despues con:"
        warn "  bash scripts/02_ssl_setup.sh TU_DOMINIO.com"
    fi
fi

echo ""
log "Modo seleccionado: $( [[ "$HAS_DOMAIN" == "true" ]] && echo "HTTPS con dominio '$DOMAIN'" || echo "HTTP sin dominio (pruebas)" )"
echo ""

# =============================================================================
# FASE 1: Docker
# =============================================================================
section "FASE 1 — Instalar Docker y dependencias"

sudo apt-get update -qq
sudo apt-get install -y -qq curl wget git ufw fail2ban ca-certificates gnupg
log "Dependencias instaladas"

if ! command -v docker &>/dev/null; then
    log "Instalando Docker Engine..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
    log "Docker instalado: $(docker --version)"
    warn "NOTA: Para usar Docker sin sudo en esta sesion ejecuta: newgrp docker"
else
    log "Docker ya instalado: $(docker --version)"
fi

if ! docker compose version &>/dev/null 2>&1; then
    sudo apt-get install -y -qq docker-compose-plugin
fi
log "Docker Compose: $(docker compose version --short)"

# =============================================================================
# FASE 2: Contrasena y directorios
# =============================================================================
section "FASE 2 — Contrasena de base de datos y directorios"

mkdir -p "$ODOO_DIR"/{addons,config,sessions,nginx/certs,nginx/templates,logs,backups,scripts}

PASS_FILE="$ODOO_DIR/odoo_pg_pass"
CURRENT_PASS=""
[[ -f "$PASS_FILE" ]] && CURRENT_PASS=$(tr -d '[:space:]' < "$PASS_FILE")

# Regenerar si no existe, esta vacia o tiene el valor placeholder del repo
if [[ ! -f "$PASS_FILE" ]] || [[ -z "$CURRENT_PASS" ]] || [[ "$CURRENT_PASS" == "CAMBIAR_POR_PASSWORD_SEGURO" ]]; then
    # Solo hexadecimal: sin /, + ni = que causan problemas en algunos contextos
    openssl rand -hex 24 > "$PASS_FILE"
    log "Contrasena generada en: $PASS_FILE"
else
    log "Contrasena existente conservada en: $PASS_FILE"
fi

# Permisos: legible por el proceso de Docker (secret mount)
chmod 644 "$PASS_FILE"
log "Permisos de odoo_pg_pass: 644 (requerido para Docker secrets)"

# =============================================================================
# FASE 3: Configuracion de Nginx
# =============================================================================
section "FASE 3 — Generando configuracion de Nginx"

if [[ "$HAS_DOMAIN" == "true" ]]; then
    # --- Modo HTTPS ---
    cat > "$ODOO_DIR/nginx/nginx.conf" << NGINXEOF
upstream odoo {
    server web:8069;
}
upstream odoo-longpolling {
    server web:8072;
}

# Redireccion HTTP -> HTTPS
server {
    listen 80;
    server_name ${DOMAIN};
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 301 https://\$host\$request_uri; }
}

# HTTPS principal
server {
    listen 443 ssl;
    server_name ${DOMAIN};

    ssl_certificate     /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:!aNULL:!MD5;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 10m;

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
    log "nginx.conf generado: modo HTTPS para $DOMAIN"
else
    # --- Modo HTTP (sin dominio / pruebas) ---
    cat > "$ODOO_DIR/nginx/nginx.conf" << 'NGINXEOF'
upstream odoo {
    server web:8069;
}
upstream odoo-longpolling {
    server web:8072;
}

server {
    listen 80;
    server_name _;

    proxy_read_timeout    720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout    720s;
    proxy_set_header X-Forwarded-Host  $host;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Real-IP         $remote_addr;

    location /longpolling/ {
        proxy_pass http://odoo-longpolling;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    location / {
        proxy_pass     http://odoo;
        proxy_redirect off;
    }

    client_max_body_size 100M;
    gzip on;
    gzip_types text/css text/plain application/json application/javascript;
}
NGINXEOF
    log "nginx.conf generado: modo HTTP (sin SSL)"
    warn "Acceso via IP: http://$(hostname -I | awk '{print $1}')"
fi

# =============================================================================
# FASE 4: Certificados SSL (solo si hay dominio)
# =============================================================================
if [[ "$HAS_DOMAIN" == "true" ]]; then
    section "FASE 4 — Certificados SSL (Let's Encrypt)"

    sudo apt-get install -y -qq certbot

    CERT_DIR="$ODOO_DIR/nginx/certs"
    if [[ ! -f "$CERT_DIR/fullchain.pem" ]]; then
        log "Obteniendo certificado para $DOMAIN..."
        sudo certbot certonly --standalone -d "$DOMAIN" \
            --non-interactive --agree-tos --email "${ADMIN_EMAIL:-admin@${DOMAIN}}"

        sudo cp "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" "$CERT_DIR/fullchain.pem"
        sudo cp "/etc/letsencrypt/live/${DOMAIN}/privkey.pem"   "$CERT_DIR/privkey.pem"
        sudo chmod 644 "$CERT_DIR"/*.pem
        sudo chown "$USER":"$USER" "$CERT_DIR"/*.pem
        log "Certificados SSL instalados en $CERT_DIR"
    else
        log "Certificados ya existen en $CERT_DIR, omitiendo."
    fi
fi

# =============================================================================
# FASE 5: Firewall
# =============================================================================
section "FASE 5 — Configurando Firewall (UFW)"

sudo ufw --force reset > /dev/null 2>&1 || true
sudo ufw default deny incoming  > /dev/null
sudo ufw default allow outgoing > /dev/null
sudo ufw allow ssh              > /dev/null
sudo ufw allow 80/tcp           > /dev/null
sudo ufw allow 443/tcp          > /dev/null
sudo ufw --force enable         > /dev/null
log "UFW activo: puertos 22/SSH, 80/HTTP, 443/HTTPS abiertos"
log "Puertos 8069 y 8072 cerrados al exterior"

# =============================================================================
# FASE 6: Iniciar servicios
# =============================================================================
section "FASE 6 — Iniciando servicios Docker"

cd "$ODOO_DIR"

# Limpiar cualquier estado anterior para garantizar inicio limpio
if docker compose ps -q 2>/dev/null | grep -q .; then
    warn "Detectados contenedores existentes. Deteniendo y eliminando volumenes..."
    docker compose down -v
fi

log "Descargando imagenes..."
docker compose pull --quiet

log "Iniciando contenedores..."
docker compose up -d

# Esperar y verificar
echo ""
log "Esperando que los servicios arranquen (hasta 90 segundos)..."
ATTEMPTS=0
MAX_ATTEMPTS=18  # 18 * 5s = 90s
while [[ $ATTEMPTS -lt $MAX_ATTEMPTS ]]; do
    sleep 5
    ATTEMPTS=$((ATTEMPTS + 1))

    DB_STATUS=$(docker compose ps --format "{{.Service}} {{.Status}}" 2>/dev/null | grep "^db " | grep -c "healthy" || true)
    WEB_STATUS=$(docker compose ps --format "{{.Service}} {{.Status}}" 2>/dev/null | grep "^web " | grep -v "Restarting\|Exit" | grep -c "Up" || true)

    echo -ne "  Intento $ATTEMPTS/$MAX_ATTEMPTS — DB: $( [[ $DB_STATUS -gt 0 ]] && echo 'healthy' || echo 'waiting...' ) | Web: $( [[ $WEB_STATUS -gt 0 ]] && echo 'running' || echo 'starting...' )\r"

    if [[ $DB_STATUS -gt 0 ]] && [[ $WEB_STATUS -gt 0 ]]; then
        echo ""
        log "Todos los servicios estan corriendo"
        break
    fi
done
echo ""

docker compose ps

# Verificar si web esta en Restarting
WEB_RESTARTING=$(docker compose ps --format "{{.Service}} {{.Status}}" 2>/dev/null | grep "^web " | grep -c "Restarting" || true)
if [[ $WEB_RESTARTING -gt 0 ]]; then
    warn "Odoo esta reiniciando. Mostrando logs para diagnostico:"
    docker compose logs --tail=20 web
    error "Odoo no pudo iniciar. Revisa los logs con: docker compose logs web"
fi

# =============================================================================
# FASE 7: Cron (backups y renovacion SSL)
# =============================================================================
section "FASE 7 — Configurando backups automaticos"

chmod +x "$ODOO_DIR/backups/backup.sh"

TMPFILE=$(mktemp)
crontab -l 2>/dev/null > "$TMPFILE" || true

if ! grep -q "backup.sh" "$TMPFILE"; then
    echo "# Odoo 19 — Backup diario 02:00 AM" >> "$TMPFILE"
    echo "0 2 * * * $ODOO_DIR/backups/backup.sh >> $ODOO_DIR/logs/backup.log 2>&1" >> "$TMPFILE"
    log "Cron de backup configurado: diario a las 02:00 AM"
fi

if [[ "$HAS_DOMAIN" == "true" ]] && ! grep -q "certbot renew" "$TMPFILE"; then
    RENEW_CMD="certbot renew --quiet && cp /etc/letsencrypt/live/${DOMAIN}/fullchain.pem $ODOO_DIR/nginx/certs/fullchain.pem && cp /etc/letsencrypt/live/${DOMAIN}/privkey.pem $ODOO_DIR/nginx/certs/privkey.pem && docker exec odoo19_nginx nginx -s reload"
    echo "" >> "$TMPFILE"
    echo "# Odoo 19 — Renovacion SSL cada 2 meses" >> "$TMPFILE"
    echo "0 3 1 */2 * $RENEW_CMD" >> "$TMPFILE"
    log "Cron de renovacion SSL configurado: cada 2 meses"
fi

crontab "$TMPFILE"
rm -f "$TMPFILE"

# =============================================================================
# RESUMEN FINAL
# =============================================================================
section "INSTALACION COMPLETADA"

SERVER_IP=$(hostname -I | awk '{print $1}')

echo -e "  ${G}Estado de contenedores:${NC}"
docker compose ps
echo ""

if [[ "$HAS_DOMAIN" == "true" ]]; then
    echo -e "  ${G}Accede a Odoo en:${NC}  https://${DOMAIN}"
else
    echo -e "  ${G}Accede a Odoo en:${NC}  http://${SERVER_IP}"
    echo ""
    warn "Cuando tengas un dominio, ejecuta para agregar SSL:"
    warn "  bash install.sh --domain TU_DOMINIO.com --email TU_EMAIL"
fi

echo ""
echo "  Comandos utiles:"
echo "    docker compose logs -f web     # logs de Odoo"
echo "    docker compose ps              # estado"
echo "    docker compose restart web     # reiniciar Odoo"
echo "    bash backups/backup.sh         # backup manual"
echo ""
echo "  IMPORTANTE: Cambia el master password en config/odoo.conf"
echo "    admin_passwd = CAMBIAR_ESTE_MASTER_PASSWORD"
echo ""
