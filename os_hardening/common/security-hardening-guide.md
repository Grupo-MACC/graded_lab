# Guía de Hardening de Seguridad Linux

## 1. Configuración de Usuarios y Shells

### Restricción de Shells
Todos los usuarios deben tener `nologin` como shell, excepto el usuario principal con acceso SSH.

**Verificación:**
```bash
cat /etc/passwd
```

**Cambiar shell a nologin:**
```bash
usermod -s /usr/sbin/nologin usuario
```

**Configurar bash restringido para el usuario principal:**
```bash
usermod -s /bin/rbash user
```
Esto obliga al usuario a escalar privilegios para realizar operaciones administrativas.

### Instalación y configuración de sudo
```bash
apt update && apt install -y sudo
cat /etc/sudoers
```
Asegurarse de que solo esté configurado root, excepto en casos excepcionales.

---

## 2. Prevención de Filesystems Vulnerables

Evitar la instalación de sistemas de archivos que pueden ser vectores de ataque.

**Crear archivo de configuración:**
```bash
nano /etc/modprobe.d/securityclass.conf
```

**Contenido del archivo:**
```bash
install cramfs echo "You won't install it, bye, bye..."
install freevxfs echo "It's not free"
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs echo "Go squat, spaghetti legs"
install udf /bin/true
install vfat /bin/true
```

---

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

---

## 4. Kernel Hardening

### Configuración de seguridad del kernel
```bash
nano /etc/sysctl.d/kernel-security.conf
```

**Contenido del archivo:**
```bash
# Deshabilitar source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# No aceptar redirecciones ICMP
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# No enviar redirecciones ICMP
net.ipv4.conf.all.send_redirects = 0

# Anti-spoofing
net.ipv4.conf.all.rp_filter = 1

# Protección contra SYN flood
net.ipv4.tcp_syncookies = 1

# No actuar como router
net.ipv4.ip_forward = 0

# Deshabilitar respuesta a ping broadcast
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Log de paquetes sospechosos
net.ipv4.conf.all.log_martians = 1
```

### Aplicar cambios
```bash
sysctl -p /etc/sysctl.d/kernel-security.conf
# o simplemente
sysctl -p
```

---

## 5. AppArmor - Control de Acceso Obligatorio

### Instalación
```bash
apt install apparmor-utils apparmor-profiles apparmor-profiles-extra
systemctl enable apparmor
systemctl start apparmor
```

### Verificar estado
```bash
aa-status
```

### Ver perfiles disponibles
```bash
ls /etc/apparmor.d/
```

### Configuración de perfiles

**Poner servicios en modo complain (aprendizaje):**
```bash
aa-complain /usr/sbin/php-fpm8.2
aa-complain /usr/sbin/mariadbd
aa-complain /usr/sbin/nginx
```

**Generar perfil personalizado para un servicio:**
```bash
aa-genprof /usr/sbin/nginx
```
Durante este proceso, usar el servicio de forma normal para que AppArmor aprenda su comportamiento y configure las reglas necesarias.

**⚠️ Precaución:** No limitar demasiado las capacidades del servicio.

### Aplicar modo enforce al resto
```bash
aa-enforce /etc/apparmor.d/*
```
### Aplicar modo complain si se ha sobreescrito (por lo visto muy probable)
```bash
aa-complain /usr/sbin/php-fpm8.2
aa-complain /usr/sbin/mariadbd
aa-complain /usr/sbin/nginx
```

### Estado final esperado
```bash
aa-status
```

**Ejemplo de configuración óptima:**
```
10 profiles are in complain mode.
   /usr/sbin/mariadbd
   /usr/sbin/nginx
   mdnsd
   nmbd
   nscd
   php-fpm
   smbd
   smbldap-useradd
   smbldap-useradd///etc/init.d/nscd
   traceroute

7 processes are in complain mode.
   /usr/sbin/mariadbd (2543) 
   /usr/sbin/nginx (1898) 
   /usr/sbin/nginx (1899) 
   /usr/sbin/nginx (1900) 
   /usr/sbin/php-fpm8.2 (505) php-fpm
   /usr/sbin/php-fpm8.2 (647) php-fpm
   /usr/sbin/php-fpm8.2 (648) php-fpm
```

---
## 6. Software update mechanism
### Install and configure unattended-upgrades
This updates the necessary packages for security

```bash
apt install unattended-upgrades
dpkg-reconfigure unattended-upgrades
nano /etc/apt/apt.conf.d/50unattended-upgrades
```
### Pegar lo siguiente
```bash
Unattended-Upgrade::Origins-Pattern {
        // Solo actualizaciones de seguridad — totalmente seguro
        "o=Ubuntu,a=${distro_codename}-security";
};

// No reiniciar automáticamente servicios ni el sistema
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
```
### Automatizar el proceso
```bash
crontab -e > 0 3 1 * * /usr/local/sbin/safe-upgrade.sh
nano /usr/local/sbin/safe-upgrade.sh #Pegar el archivo
chmod +x /usr/local/sbin/safe-upgrade.sh
```
## Resumen

Esta guía cubre los aspectos esenciales del hardening de seguridad en Linux:

1. **Control de usuarios:** Shells restringidos y gestión de privilegios
2. **Prevención de filesystems:** Bloqueo de sistemas de archivos vulnerables
3. **Integridad:** Monitoreo con AIDE para detectar cambios no autorizados
4. **Kernel:** Protecciones a nivel de kernel contra ataques de red
5. **AppArmor:** Control de acceso obligatorio para limitar el alcance de los procesos
6. **Mecanismo de actualizacion de software:** Actualizacion de paquetes que pueden comprometer la seguridad

Implementar estas medidas proporciona múltiples capas de seguridad (defensa en profundidad) para proteger el sistema contra diversos vectores de ataque.