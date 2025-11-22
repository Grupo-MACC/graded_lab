Todos los usuarios deben tener nologin como bash, excepto user (accedemos por ssh con el)
se verifica en /etc/passwd
se cambia con: usermod -s /usr/sbin/nologin user
apt update && apt install -y sudo
cat /etc/sudoers > asegurarse que solo este root, excepto casos excepcionales
usermod -s /bin/rbash user > poner restricted bash a user para que tenga que escalar privilegios para hacer operaciones.

Evitar instalacion de filesystems indebidos, que pueden ser vectores de ataque y vulnerables
$ nano /etc/modprobe.d/securityclass.conf
install cramfs echo "You won't install it, bye, bye..."
install freevxfs echo "It's not free"
install jffs2 /bien/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs echo "Go squat, spaghetti legs"
install udf /bin/true
install vfat /bin/true

Integridad de archivos
sudo apt install aide aide-common -y
aideinit (tomara tiempo, hashea muchos archivos)
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
nano /etc/aide/aide.conf > anadir los ficheros a monitoriear (comunes y dependiendo del servicio)

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


aideinit
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

aide --config=/etc/aide/aide.conf --check > ver si han habido cambios
prueba de aide
cambiar un archivo o crear uno en un directorio mencionado y lanzar el check
root@Web:~# nano /etc/nginx/hola
root@Web:~# aide --config=/etc/aide/aide.conf --check
Start timestamp: 2025-11-19 17:01:07 +0100 (AIDE 0.18.3)
AIDE found differences between database and filesystem!!
Ignored e2fs attributes: EINV

Summary:
  Total number of entries:	40310
  Added entries:		4
  Removed entries:		4
  Changed entries:		60

---------------------------------------------------
Added entries:
---------------------------------------------------

f+++++++++++++++++: /etc/nginx/hola
automatizar el proceso
$mkdir -p /var/log/aide
$crontab -e
escribir : 0 3 * * * /usr/bin/aide --config=/etc/aide/aide.conf --check > /var/log/aide/aide-$(date +\%F).log

Kernel hardening

root@Web:~# nano /etc/sysctl.d/kernel-security.conf
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

# Opcional pero recomendado:
# Deshabilitar respuesta a ping exagerada
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Log de paquetes sospechosos
net.ipv4.conf.all.log_martians = 1

aplicar los cambios
root@Web:~# sysctl -p /etc/sysctl.d/kernel-security.conf o sysctl -p

apparmor
root@Web:~# aa-status
apt install apparmor-utils apparmor-profiles apparmor-profiles-extra
systemctl enable apparmor
systemctl start apparmor
ver los perfiles : root@Web:~# ls /etc/apparmor.d/
abi		    sbin.syslog-ng
abstractions	    tunables
apache2.d	    usr.bin.irssi
bin.ping	    usr.bin.man
disable		    usr.bin.pidgin
force-complain	    usr.bin.totem
local		    usr.bin.totem-previewers
lsb_release	    usr.sbin.apt-cacher-ng
nvidia_modprobe     usr.sbin.avahi-daemon
php-fpm		    usr.sbin.dnsmasq
samba-bgqd	    usr.sbin.identd
samba-dcerpcd	    usr.sbin.mariadbd
samba-rpcd	    usr.sbin.mdnsd
samba-rpcd-classic  usr.sbin.nmbd
samba-rpcd-spoolss  usr.sbin.nscd
sbin.dhclient	    usr.sbin.smbd
sbin.klogd	    usr.sbin.smbldap-useradd
sbin.syslogd	    usr.sbin.traceroute

Aplicar los perfiles: enforce > conseguimos que los procesos no salgan de donde deberian, qu eno usen redes, archivos qu eno deben...
Poner el complain nuestros servicios
aa-complain /usr/sbin/php-fpm8.2
aa-complain /usr/sbin/mariadbd
Cuidado, verificar qu enuestros ervicios tienen perfil, sino 
aa-genprof /usr/sbin/nginx > Aqui se debe usar el servicio de forma normal y se analizara lo que el servicio hace y se pdora configurar lo que se le deja o no hacer. cuidado con limitar mucho.
ahora si aparecera:

root@Web:~# ls /etc/apparmor.d/
abi		nvidia_modprobe     sbin.klogd	    usr.bin.totem-previewers  usr.sbin.nmbd
abstractions	php-fpm		    sbin.syslogd    usr.sbin.apt-cacher-ng    usr.sbin.nscd
apache2.d	samba-bgqd	    sbin.syslog-ng  usr.sbin.avahi-daemon     usr.sbin.smbd
bin.ping	samba-dcerpcd	    tunables	    usr.sbin.dnsmasq	      usr.sbin.smbldap-useradd
disable		samba-rpcd	    usr.bin.irssi   usr.sbin.identd	      usr.sbin.traceroute
force-complain	samba-rpcd-classic  usr.bin.man     usr.sbin.mariadbd
local		samba-rpcd-spoolss  usr.bin.pidgin  usr.sbin.mdnsd
lsb_release	sbin.dhclient	    usr.bin.totem   usr.sbin.nginx

aa-complain /usr/sbin/nginx

en enforce el resto:
aa-enforce /etc/apparmor.d/*
finalmente se deberia tener algo asi:

aa-status
   nvidia_modprobe
   nvidia_modprobe//kmod
   ping
   samba-bgqd
   samba-dcerpcd
   samba-rpcd
   samba-rpcd-classic
   samba-rpcd-spoolss
   syslog-ng
   syslogd
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
0 profiles are in kill mode.
0 profiles are in unconfined mode.
7 processes have profiles defined.
0 processes are in enforce mode.
7 processes are in complain mode.
   /usr/sbin/mariadbd (2543) 
   /usr/sbin/nginx (1898) 
   /usr/sbin/nginx (1899) 
   /usr/sbin/nginx (1900) 
   /usr/sbin/php-fpm8.2 (505) php-fpm
   /usr/sbin/php-fpm8.2 (647) php-fpm
   /usr/sbin/php-fpm8.2 (648) php-fpm
0 processes are unconfined but have a profile defined.
0 processes are in mixed mode.
0 processes are in kill mode.
