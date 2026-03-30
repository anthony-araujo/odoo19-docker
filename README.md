# Instalacion Profesional: Odoo 19 en Ubuntu 24.04 con Docker

## Estructura del proyecto

```
/opt/odoo/
├── addons/               # Modulos personalizados de Odoo
├── backups/
│   └── backup.sh         # Script de backup automatico
├── config/
│   └── odoo.conf         # Configuracion principal de Odoo
├── logs/                 # Logs del contenedor de Odoo
├── nginx/
│   ├── certs/            # Certificados SSL (generados por Certbot)
│   └── nginx.conf        # Configuracion del reverse proxy
├── scripts/
│   ├── 01_server_setup.sh   # Instala Docker y prepara directorios
│   ├── 02_ssl_setup.sh      # Obtiene certificados Let's Encrypt
│   ├── 03_firewall_setup.sh # Configura UFW
│   ├── 04_start_services.sh # Inicia los contenedores Docker
│   └── 05_setup_cron.sh     # Programa backups y renovacion SSL
├── sessions/             # Sesiones HTTP de Odoo
├── docker-compose.yaml
└── odoo_pg_pass          # Contrasena de PostgreSQL (NO commitear)
```

---

## Pasos de instalacion en el servidor Ubuntu 24.04

### Prerequisito: Copiar este proyecto al servidor

```bash
# Desde tu maquina local:
scp -r ./docker usuario@IP_SERVIDOR:/opt/odoo

# O clonar directamente en el servidor si esta en un repositorio
```

### Paso 0: Editar valores obligatorios antes de comenzar

Antes de ejecutar cualquier script, editar los siguientes archivos:

**`config/odoo.conf`** — cambiar el `admin_passwd`:
```ini
admin_passwd = TU_MASTER_PASSWORD_SEGURO
```

**`nginx/nginx.conf`** — cambiar `TU_DOMINIO.com` por el dominio real:
```nginx
server_name tu-dominio-real.com;
```
> El script `02_ssl_setup.sh` también lo reemplaza automáticamente.

---

### Paso 1: Preparacion del servidor (Docker + directorios)

```bash
cd /opt/odoo
bash scripts/01_server_setup.sh
```

Este script:
- Actualiza Ubuntu y instala dependencias
- Instala Docker Engine (metodo oficial)
- Instala Docker Compose v2
- Crea todos los directorios necesarios
- Genera una contrasena aleatoria segura en `odoo_pg_pass`

> **Nota:** Despues de ejecutarlo, cierra la sesion SSH y vuelve a entrar para que el grupo `docker` tome efecto.

---

### Paso 2: Certificados SSL

El dominio debe apuntar a la IP del servidor (registro DNS tipo A) antes de este paso.

```bash
bash scripts/02_ssl_setup.sh TU_DOMINIO.com
```

Este script:
- Instala Certbot
- Obtiene el certificado Let's Encrypt
- Copia los certificados a `nginx/certs/`
- Actualiza el dominio en `nginx/nginx.conf`

---

### Paso 3: Firewall

```bash
bash scripts/03_firewall_setup.sh
```

Resultado: solo los puertos 22 (SSH), 80 (HTTP) y 443 (HTTPS) quedan abiertos. Los puertos 8069 y 8072 de Odoo solo son accesibles internamente por Nginx.

---

### Paso 4: Iniciar los servicios

```bash
bash scripts/04_start_services.sh
```

Este script:
- Descarga las imagenes de Docker
- Inicia los tres contenedores: `odoo19_db`, `odoo19_web`, `odoo19_nginx`
- Verifica el estado y muestra los logs iniciales

Acceder a Odoo: `https://TU_DOMINIO.com`

---

### Paso 5: Programar backups y renovacion SSL

```bash
bash scripts/05_setup_cron.sh TU_DOMINIO.com
```

Configura:
- Backup automatico diario a las 02:00 AM
- Renovacion automatica de SSL cada 2 meses

---

## Comandos de operacion diaria

```bash
# Estado de los contenedores
docker compose ps

# Ver logs en tiempo real
docker compose logs -f web
docker compose logs -f db

# Reiniciar Odoo (sin tocar la BD)
docker compose restart web

# Detener todo
docker compose down

# Iniciar todo
docker compose up -d

# Actualizar imagen de Odoo (con backup previo!)
docker compose pull && docker compose up -d

# Ejecutar backup manual
bash /opt/odoo/backups/backup.sh
```

---

## Notas de seguridad importantes

- El archivo `odoo_pg_pass` contiene la contrasena de la base de datos. No lo subas a ningun repositorio.
- El `admin_passwd` en `config/odoo.conf` es la contrasena maestra de Odoo. Usa un valor aleatorio y guardalo en un gestor de contrasenas.
- `list_db = False` en `odoo.conf` esta configurado para evitar que usuarios anonimos vean las bases de datos disponibles.
- Los puertos 8069 y 8072 estan enlazados solo a `127.0.0.1` en `docker-compose.yaml`; no son accesibles desde Internet.

---

## Requisitos minimos del servidor

| Recurso | Minimo | Recomendado |
|---------|--------|-------------|
| CPU     | 2 vCPU | 4 vCPU      |
| RAM     | 4 GB   | 8 GB        |
| Disco   | 40 GB  | 100 GB SSD  |
| SO      | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |
