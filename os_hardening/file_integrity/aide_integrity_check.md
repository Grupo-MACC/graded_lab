## 3. Integridad de Archivos con AIDE

### Instalación
```bash
sudo apt install aide aide-common -y
```

### Inicialización de la base de datos
```bash
aideinit
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

### Configuración de archivos a monitorear
```bash
nano /etc/aide/aide.conf
```

**Ejemplo de configuración:**
```bash
# Nginx
/etc/nginx/                       Full
/etc/nginx/sites-available/       Full
/etc/nginx/sites-enabled/         Full

# PHP-FPM
/etc/php/                         Full

# Web application
/var/www/web/airport_web/         VarFile
/var/www/web/airport_web/db_connection.php Full
/var/www/web/airport_web/index.php Full

# Logs
/var/log/nginx/                   ActLog
/var/log/php*                     ActLog

# Core system
/etc/                             Full
/bin/                             StaticFile
/sbin/                            StaticFile
/usr/bin/                         StaticFile
/usr/sbin/                        StaticFile
/lib/                             StaticFile
/lib64/                           StaticFile
/boot/                            StaticFile

# Cron & systemd
/etc/spool/cron/                  Full
/etc/systemd/                     Full

# SSH
/etc/ssh/sshd_config              Full

# Firewall
/etc/ufw/                         Full
/etc/nftables.conf                Full

# Temporary dirs
/tmp/                             VarFile
/var/tmp/                         VarFile
/var/lib/php/                     VarFile
```

### Reinicializar y verificar
```bash
aideinit
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
aide --config=/etc/aide/aide.conf --check
```

### Prueba de AIDE
```bash
# Crear un archivo de prueba
nano /etc/nginx/hola

# Ejecutar verificación
aide --config=/etc/aide/aide.conf --check
```

**Salida esperada:**
```
AIDE found differences between database and filesystem!!
Added entries:
f+++++++++++++++++: /etc/nginx/hola
```

### Automatización con Cron
```bash
mkdir -p /var/log/aide
crontab -e
```

**Agregar la siguiente línea:**
```bash
0 3 * * * /usr/bin/aide --config=/etc/aide/aide.conf --check > /var/log/aide/aide-$(date +\%F).log
```
Esto ejecutará AIDE diariamente a las 3:00 AM.
