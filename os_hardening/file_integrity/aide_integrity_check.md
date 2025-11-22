## 3. File Integrity with AIDE

### Installation
```bash
sudo apt install aide aide-common -y
```

### Database initialization
```bash
aideinit
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

### Configuring files to monitor
```bash
nano /etc/aide/aide.conf
```

**Configuration example:**
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

### Reinitialize and verify
```bash
aideinit
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
aide --config=/etc/aide/aide.conf --check
```

### AIDE testing
```bash
# Create a test file
nano /etc/nginx/hello

# Run verification
aide --config=/etc/aide/aide.conf --check
```

**Expected output:**
```
AIDE found differences between database and filesystem!!
Added entries:
f+++++++++++++++++: /etc/nginx/hello
```

### Automation with Cron
```bash
mkdir -p /var/log/aide
crontab -e
```

**Add the following line:**
```bash
0 3 * * * /usr/bin/aide --config=/etc/aide/aide.conf --check > /var/log/aide/aide-$(date +\%F).log
```
This will run AIDE daily at 3:00 AM.