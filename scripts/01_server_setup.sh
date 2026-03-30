#!/usr/bin/env bash
# =============================================================================
# FASE 1 y 2: Preparacion del servidor Ubuntu 24.04
# Ejecutar como usuario con sudo (NO como root)
# Uso: bash 01_server_setup.sh
# =============================================================================
set -euo pipefail

echo "=== [1/5] Actualizando el sistema ==="
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git ufw fail2ban

echo "=== [2/5] Instalando Docker Engine ==="
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
    echo "NOTA: Cierra la sesion y vuelve a entrar para que el grupo docker tome efecto,"
    echo "      o ejecuta: newgrp docker"
else
    echo "Docker ya esta instalado: $(docker --version)"
fi

echo "=== [3/5] Instalando Docker Compose v2 plugin ==="
sudo apt install -y docker-compose-plugin
docker compose version

echo "=== [4/5] Creando estructura de directorios ==="
sudo mkdir -p /opt/odoo/{addons,config,sessions,nginx/certs,logs,backups,scripts}
sudo chown -R "$USER":"$USER" /opt/odoo

echo "=== [5/5] Generando contrasena segura para PostgreSQL ==="
PASS_FILE=/opt/odoo/odoo_pg_pass
if [ ! -f "$PASS_FILE" ]; then
    openssl rand -base64 32 | tr -d '=' > "$PASS_FILE"
    chmod 600 "$PASS_FILE"
    echo "Contrasena generada en: $PASS_FILE"
else
    echo "El archivo $PASS_FILE ya existe, no se sobreescribe."
fi

echo ""
echo "=== FASE 1-2 COMPLETADA ==="
echo "Siguiente paso: copiar los archivos del proyecto a /opt/odoo/ y ejecutar 02_ssl_setup.sh"
