#!/usr/bin/env bash
# =============================================================================
# status.sh — Estado completo de la instalacion de Odoo 19
# Uso: bash scripts/status.sh
# =============================================================================
set -euo pipefail

ODOO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
G='\033[0;32m'; R='\033[0;31m'; Y='\033[1;33m'; B='\033[0;34m'; NC='\033[0m'

echo ""
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${B}  Estado de Odoo 19 — $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

SERVER_IP=$(hostname -I | awk '{print $1}')
echo "  Servidor  : $SERVER_IP"
echo "  Proyecto  : $ODOO_DIR"
echo ""

# Contenedores
echo -e "${B}Contenedores:${NC}"
cd "$ODOO_DIR"
docker compose ps
echo ""

# Uso de recursos
echo -e "${B}Uso de recursos:${NC}"
docker stats --no-stream --format "  {{.Name}}\tCPU: {{.CPUPerc}}\tRAM: {{.MemUsage}}" \
    odoo19_web odoo19_db odoo19_nginx 2>/dev/null || echo "  (contenedores no activos)"
echo ""

# Uso de disco
echo -e "${B}Volumenes Docker:${NC}"
docker volume ls --filter name=odoo19 --format "  {{.Name}}" | while read -r vol; do
    SIZE=$(docker run --rm -v "${vol}:/data" alpine du -sh /data 2>/dev/null | cut -f1)
    echo "  $vol: $SIZE"
done
echo ""

# SSL
CERT="$ODOO_DIR/nginx/certs/fullchain.pem"
echo -e "${B}SSL:${NC}"
if [[ -f "$CERT" ]]; then
    EXPIRY=$(openssl x509 -enddate -noout -in "$CERT" 2>/dev/null | cut -d= -f2)
    echo -e "  ${G}Certificado instalado${NC} — expira: $EXPIRY"
else
    echo -e "  ${Y}Sin certificado SSL (modo HTTP)${NC}"
fi
echo ""

# Logs recientes de errores
echo -e "${B}Ultimos errores en Odoo (si hay):${NC}"
docker compose logs --tail=5 web 2>/dev/null | grep -i "error\|critical\|fatal" || echo "  Sin errores recientes"
echo ""

# Firewall
echo -e "${B}Firewall (UFW):${NC}"
sudo ufw status 2>/dev/null | grep -E "Status|80|443|22" | sed 's/^/  /' || echo "  UFW no disponible"
echo ""
