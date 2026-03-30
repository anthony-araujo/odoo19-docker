#!/usr/bin/env bash
# =============================================================================
# FASE 5: Configuracion del Firewall con UFW
# Abre solo SSH, HTTP (80) y HTTPS (443).
# Los puertos 8069 y 8072 de Odoo NO se abren al exterior.
# Uso: bash 03_firewall_setup.sh
# =============================================================================
set -euo pipefail

echo "=== [1/4] Estableciendo politica por defecto ==="
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "=== [2/4] Permitiendo SSH ==="
sudo ufw allow ssh
# Si SSH corre en un puerto distinto al 22, cambia el comando:
# sudo ufw allow 2222/tcp

echo "=== [3/4] Permitiendo HTTP y HTTPS ==="
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

echo "=== [4/4] Activando UFW ==="
# Los puertos 8069 y 8072 quedan cerrados al exterior.
# Nginx redirige el trafico internamente via red Docker.
sudo ufw --force enable
sudo ufw status verbose

echo ""
echo "=== FIREWALL CONFIGURADO ==="
echo "Puertos abiertos: 22 (SSH), 80 (HTTP), 443 (HTTPS)"
echo "Puertos cerrados al exterior: 8069, 8072"
echo "Siguiente paso: ejecutar 04_start_services.sh"
