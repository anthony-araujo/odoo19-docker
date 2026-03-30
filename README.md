# Odoo 19 en Ubuntu 24.04 con Docker

Instalacion profesional con Nginx, SSL, backups automaticos y firewall.

## Estructura del proyecto

```
/opt/odoo19-docker/          # (o la ruta donde clonaste el repo)
├── addons/                  # Modulos personalizados de Odoo
├── backups/
│   └── backup.sh            # Script de backup automatico
├── config/
│   └── odoo.conf            # Configuracion principal de Odoo
├── logs/                    # Logs del contenedor de Odoo
├── nginx/
│   ├── certs/               # Certificados SSL (generados por Certbot)
│   └── nginx.conf           # Reverse proxy
├── scripts/
│   ├── 01_server_setup.sh   # Docker + contrasena de BD
│   ├── 02_ssl_setup.sh      # Certificados Let's Encrypt
│   ├── 03_firewall_setup.sh # UFW
│   ├── 04_start_services.sh # Iniciar contenedores
│   └── 05_setup_cron.sh     # Backups y renovacion SSL automatica
├── sessions/                # Sesiones HTTP de Odoo
├── docker-compose.yaml
└── odoo_pg_pass             # Contrasena de PostgreSQL — NO commitear
```

> Los scripts detectan automaticamente la ruta del proyecto.
> Funcionan desde cualquier directorio donde este clonado el repo.

---

## Guia de instalacion paso a paso

### Prerequisito: tener el repo clonado en el servidor

```bash
cd /opt
sudo git clone git@github.com:anthony-araujo/odoo19-docker.git
sudo chown -R $USER:$USER /opt/odoo19-docker
cd /opt/odoo19-docker
```

---

### Paso 0 — Editar valores obligatorios

**`config/odoo.conf`** — cambiar el master password:
```bash
nano config/odoo.conf
# Cambiar: admin_passwd = CAMBIAR_ESTE_MASTER_PASSWORD
# Por un valor seguro, ejemplo:
# admin_passwd = $(openssl rand -base64 18)
```

**`nginx/nginx.conf`** — el script 02 lo actualiza automaticamente con tu dominio.

---

### Paso 1 — Instalar Docker y generar contrasena de BD

```bash
bash scripts/01_server_setup.sh
```

Instala Docker Engine, Docker Compose v2 y genera `odoo_pg_pass` con una
clave aleatoria segura. Si Docker ya estaba instalado lo omite.

> Despues de este paso, cierra la sesion SSH y vuelve a entrar
> (o ejecuta `newgrp docker`) para que el grupo `docker` tome efecto.

---

### Paso 2 — Certificados SSL

El dominio debe tener un registro DNS tipo A apuntando a la IP del servidor.

```bash
bash scripts/02_ssl_setup.sh tu-dominio.com
```

Instala Certbot, obtiene el certificado Let's Encrypt, copia los `.pem`
a `nginx/certs/` y actualiza el dominio en `nginx/nginx.conf`.

---

### Paso 3 — Firewall

```bash
bash scripts/03_firewall_setup.sh
```

Abre solo los puertos **22 (SSH)**, **80 (HTTP)** y **443 (HTTPS)**.
Los puertos 8069 y 8072 de Odoo quedan cerrados al exterior.

---

### Paso 4 — Iniciar los servicios

```bash
bash scripts/04_start_services.sh
```

Descarga las imagenes Docker e inicia los tres contenedores:
`odoo19_db`, `odoo19_web`, `odoo19_nginx`.

Accede a Odoo en `https://tu-dominio.com` y crea la primera base de datos.

---

### Paso 5 — Programar backups y renovacion SSL

```bash
bash scripts/05_setup_cron.sh tu-dominio.com
```

Configura:
- Backup automatico diario a las **02:00 AM**
- Renovacion automatica de SSL cada **2 meses**

---

## Comandos de operacion diaria

```bash
cd /opt/odoo19-docker

# Estado de los contenedores
docker compose ps

# Logs en tiempo real
docker compose logs -f web
docker compose logs -f db

# Reiniciar solo Odoo (sin tocar la BD)
docker compose restart web

# Detener todos los servicios
docker compose down

# Iniciar todos los servicios
docker compose up -d

# Backup manual
bash backups/backup.sh

# Actualizar imagen de Odoo (hacer backup antes)
docker compose pull web && docker compose up -d web
```

---

## Notas de seguridad

- `odoo_pg_pass` contiene la contrasena de la BD. Nunca lo subas a un repo.
  Esta en `.gitignore` para protegerlo.
- `admin_passwd` en `config/odoo.conf` es la contrasena maestra de Odoo.
  Guardala en un gestor de contrasenas.
- `list_db = False` en `odoo.conf` oculta el listado de bases de datos.
- Los puertos 8069 y 8072 solo escuchan en `127.0.0.1`, no al exterior.

---

## Requisitos minimos del servidor

| Recurso | Minimo   | Recomendado |
|---------|----------|-------------|
| CPU     | 2 vCPU   | 4 vCPU      |
| RAM     | 4 GB     | 8 GB        |
| Disco   | 40 GB    | 100 GB SSD  |
| SO      | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |
