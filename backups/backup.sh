#!/usr/bin/env bash
# =============================================================================
# Script de backup automatico para Odoo 19
# Guarda: dump completo de PostgreSQL + filestore de Odoo
# Retencion: 7 dias por defecto (RETENTION_DAYS)
# Uso manual: bash /opt/odoo/backups/backup.sh
# Crontab:    0 2 * * * /opt/odoo/backups/backup.sh >> /opt/odoo/logs/backup.log 2>&1
# =============================================================================
set -euo pipefail

ODOO_DIR="/opt/odoo"
BACKUP_DIR="$ODOO_DIR/backups"
DB_CONTAINER="odoo19_db"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "=== Iniciando backup: $DATE ==="

# Verificar que el contenedor de DB este corriendo
if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    log "ERROR: El contenedor $DB_CONTAINER no esta corriendo. Abortando."
    exit 1
fi

# --- Backup de PostgreSQL ---
DB_BACKUP="$BACKUP_DIR/db_$DATE.sql.gz"
log "Generando dump de PostgreSQL -> $DB_BACKUP"
docker exec "$DB_CONTAINER" pg_dumpall -U odoo | gzip > "$DB_BACKUP"
log "Dump completado: $(du -sh "$DB_BACKUP" | cut -f1)"

# --- Backup del filestore (archivos adjuntos de Odoo) ---
FILESTORE_BACKUP="$BACKUP_DIR/filestore_$DATE.tar.gz"
log "Comprimiendo filestore -> $FILESTORE_BACKUP"
# El filestore esta en el volumen Docker, accesible via el contenedor web
docker run --rm \
    --volumes-from odoo19_web \
    -v "$BACKUP_DIR":/backup \
    alpine \
    tar -czf /backup/filestore_"$DATE".tar.gz /var/lib/odoo
log "Filestore comprimido: $(du -sh "$FILESTORE_BACKUP" | cut -f1)"

# --- Limpieza de backups antiguos ---
log "Eliminando backups de mas de $RETENTION_DAYS dias..."
find "$BACKUP_DIR" -name "db_*.sql.gz"       -mtime +"$RETENTION_DAYS" -delete
find "$BACKUP_DIR" -name "filestore_*.tar.gz" -mtime +"$RETENTION_DAYS" -delete

log "=== Backup $DATE completado exitosamente ==="
log "Archivos en $BACKUP_DIR:"
ls -lh "$BACKUP_DIR"/*.gz 2>/dev/null || log "(no hay archivos)"
