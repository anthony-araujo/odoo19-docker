# Odoo 19 — Ubuntu 24.04 con Docker

Instalacion profesional con Nginx, SSL opcional, backups automaticos y firewall.

## Inicio rapido

```bash
# 1. Clonar el repositorio en el servidor
cd /opt
sudo git clone git@github.com:anthony-araujo/odoo19-docker.git
sudo chown -R $USER:$USER /opt/odoo19-docker
cd /opt/odoo19-docker

# 2. Editar el master password de Odoo (OBLIGATORIO)
nano config/odoo.conf
# Cambiar: admin_passwd = CAMBIAR_ESTE_MASTER_PASSWORD

# 3. Ejecutar el instalador
bash install.sh
```

El instalador pregunta si tienes dominio. Responde y se configura todo automaticamente.

---

## Opciones del instalador

```bash
# Modo interactivo (pregunta dominio, email, etc.)
bash install.sh

# Con dominio desde el inicio (HTTPS automatico)
bash install.sh --domain erp.miempresa.com --email admin@miempresa.com

# Sin dominio (HTTP, para pruebas por IP)
bash install.sh --no-domain
```

---

## Agregar dominio y SSL a una instalacion existente

Si instalaste en modo `--no-domain` y ya tienes el dominio apuntando al servidor:

```bash
bash scripts/add_domain.sh erp.miempresa.com admin@miempresa.com
```

---

## Estructura del proyecto

```
/opt/odoo19-docker/
├── install.sh               # Instalador principal — ejecutar esto
├── docker-compose.yaml      # Definicion de servicios Docker
├── odoo_pg_pass             # Contrasena BD (generada automaticamente, NO commitear)
├── addons/                  # Modulos personalizados de Odoo
├── backups/
│   └── backup.sh            # Script de backup automatico
├── config/
│   └── odoo.conf            # Configuracion de Odoo
├── logs/                    # Logs del contenedor
├── nginx/
│   ├── certs/               # Certificados SSL (generados por Certbot)
│   └── nginx.conf           # Generado por install.sh segun modo HTTP/HTTPS
├── scripts/
│   ├── 01_server_setup.sh   # Solo Docker + contrasena (paso individual)
│   ├── 02_ssl_setup.sh      # Solo SSL (paso individual)
│   ├── 03_firewall_setup.sh # Solo UFW (paso individual)
│   ├── 04_start_services.sh # Solo iniciar Docker (paso individual)
│   ├── 05_setup_cron.sh     # Solo cron (paso individual)
│   ├── add_domain.sh        # Agregar dominio a instalacion existente
│   └── status.sh            # Ver estado completo del sistema
└── sessions/                # Sesiones HTTP de Odoo
```

---

## Comandos de operacion diaria

```bash
cd /opt/odoo19-docker

# Estado completo del sistema
bash scripts/status.sh

# Logs en tiempo real
docker compose logs -f web
docker compose logs -f db
docker compose logs -f nginx

# Estado de contenedores
docker compose ps

# Reiniciar solo Odoo (sin tocar la BD)
docker compose restart web

# Detener todo
docker compose down

# Iniciar todo
docker compose up -d

# Reiniciar limpio (BORRA DATOS — solo si es instalacion nueva)
bash scripts/04_start_services.sh --clean

# Backup manual
bash backups/backup.sh
```

---

## Notas de seguridad

| Archivo | Detalle |
|---|---|
| `odoo_pg_pass` | Contrasena de PostgreSQL. Permisos `644`, generada con `openssl rand -hex 24`. Esta en `.gitignore`. |
| `config/odoo.conf` `admin_passwd` | Master password de Odoo. Cambiarlo ANTES del primer inicio. |
| `list_db = False` | Oculta el listado de bases de datos en produccion. |
| Puertos 8069/8072 | Solo en `127.0.0.1`. No accesibles desde Internet, solo via Nginx. |

---

## Requisitos del servidor

| Recurso | Minimo (pruebas) | Produccion |
|---------|-----------------|------------|
| CPU     | 2 vCPU          | 4+ vCPU    |
| RAM     | 2 GB            | 8+ GB      |
| Disco   | 30 GB SSD       | 100+ GB SSD|
| SO      | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |

> Con 2 GB RAM el instalador configura `workers = 2`. Aumentar a 4+ con 8 GB RAM
> editando `config/odoo.conf` y reiniciando: `docker compose restart web`

---

## Problemas comunes

**`Permission denied` en `/run/secrets/postgresql_password`**
```bash
chmod 644 odoo_pg_pass
docker compose restart web
```

**`password authentication failed for user "odoo"`**
```bash
# El volumen de Postgres tiene una contrasena diferente. Reiniciar limpio:
docker compose down -v
docker compose up -d
```

**Nginx muestra "Welcome to nginx!" en vez de Odoo**
```bash
docker exec odoo19_nginx rm -f /etc/nginx/conf.d/default.conf
docker exec odoo19_nginx nginx -s reload
```

**502 Bad Gateway**
```bash
# Odoo puede estar arrancando. Esperar 60s y revisar logs:
docker compose logs --tail=30 web
```
