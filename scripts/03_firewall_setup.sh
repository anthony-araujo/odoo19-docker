#!/usr/bin/env bash
# =============================================================================
# 03_firewall_setup.sh — Configurar UFW
# Abre: 22/SSH, 80/HTTP, 443/HTTPS
# Cierra: 8069, 8072 (Odoo solo accesible via Nginx)
# Uso: bash scripts/03_firewall_setup.sh
# =============================================================================
set -euo pipefail

G='\033[0;32m'; NC='\033[0m'
log() { echo -e "${G}[OK]${NC} $*"; }

echo "=== Configurando UFW ==="
sudo ufw --force reset > /dev/null 2>&1 || true
sudo ufw default deny incoming  > /dev/null
sudo ufw default allow outgoing > /dev/null
sudo ufw allow ssh              > /dev/null
sudo ufw allow 80/tcp           > /dev/null
sudo ufw allow 443/tcp          > /dev/null
sudo ufw --force enable         > /dev/null

log "UFW activo"
sudo ufw status verbose
