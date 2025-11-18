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
automatizar