# Linux Security Hardening Guide

## 1. User and Shell Configuration

### Shell Restriction
All users should have `nologin` as their shell, except for the main user with SSH access.

**Verification:**
```bash
cat /etc/passwd
```

**Change shell to nologin if needed:**
```bash
usermod -s /usr/sbin/nologin username
```

**Configure restricted bash for the main user:**
```bash
usermod -s /bin/rbash user
```
This forces the user to escalate privileges to perform administrative operations.

### Installing and configuring sudo
```bash
apt update && apt install -y sudo
cat /etc/sudoers
```
Ensure that only root is configured, except in exceptional cases.
---

## 2. Preventing Vulnerable Filesystems

Prevent installation of file systems that can be attack vectors. We use the fake install method.

**Create configuration file:**
```bash
nano /etc/modprobe.d/securityclass.conf
```

**File contents:**
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
---

## 4. Kernel Hardening

### Kernel security configuration
```bash
nano /etc/sysctl.d/kernel-security.conf
```

**File contents:**
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

### Apply changes
```bash
sysctl -p /etc/sysctl.d/kernel-security.conf
# or simply
sysctl -p
```

---

## 5. AppArmor - Mandatory Access Control

### Installation
```bash
apt install apparmor-utils apparmor-profiles apparmor-profiles-extra
systemctl enable apparmor
systemctl start apparmor
```

### Verify status
```bash
aa-status
```

### View available profiles
```bash
ls /etc/apparmor.d/
```

### Profile configuration

**Put services in complain mode (learning):**
```bash
aa-complain /usr/sbin/php-fpm8.2
aa-complain /usr/sbin/mariadbd
aa-complain /usr/sbin/nginx
```

**Generate custom profile for a service, only if the profile doesn't exist:**
```bash
aa-genprof /usr/sbin/nginx
```
During this process, use the service normally so that AppArmor learns its behavior and configures the necessary rules.

**⚠️ Caution:** Do not overly restrict service capabilities.

### Apply enforce mode to the rest
```bash
aa-enforce /etc/apparmor.d/*
```

### Reapply complain mode if overwritten (apparently very likely)
```bash
aa-complain /usr/sbin/php-fpm8.2
aa-complain /usr/sbin/mariadbd
aa-complain /usr/sbin/nginx
```

### Expected final state
```bash
aa-status
```

**Optimal configuration example:**
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

## 6. Software Update Mechanism

### Install and configure unattended-upgrades
This updates necessary packages for security.

```bash
apt install unattended-upgrades
dpkg-reconfigure unattended-upgrades
nano /etc/apt/apt.conf.d/50unattended-upgrades
```

### Paste the following
```bash
Unattended-Upgrade::Origins-Pattern {
        // Solo actualizaciones de seguridad — totalmente seguro
        "o=Ubuntu,a=${distro_codename}-security";
};

// No reiniciar automáticamente servicios ni el sistema
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
```

### Automate the process
```bash
crontab -e
```
Add:
```bash
0 3 1 * * /usr/local/sbin/safe-upgrade.sh
```

Create the script:
```bash
nano /usr/local/sbin/safe-upgrade.sh
```

Paste:
```bash
#!/bin/bash

set -e

# Log
echo "===== Safe upgrade started: $(date) =====" >> /var/log/safe-upgrade.log

# 1. Actualizar índices
apt update -y >> /var/log/safe-upgrade.log 2>&1

# 2. Realizar upgrade seguro (NO dist-upgrade)
apt upgrade -y >> /var/log/safe-upgrade.log 2>&1

# 3. Recargar servicios sin interrumpir conexiones
systemctl reload nginx 2>/dev/null || true
systemctl reload mariadb 2>/dev/null || true
systemctl reload php*-fpm.service 2>/dev/null || true

echo "===== Safe upgrade finished: $(date) =====" >> /var/log/safe-upgrade.log
```

Make executable:
```bash
chmod +x /usr/local/sbin/safe-upgrade.sh
```

---

## Summary

This guide covers essential aspects of Linux security hardening:

1. **User control:** Restricted shells and privilege management
2. **Filesystem prevention:** Blocking vulnerable file systems
3. **Integrity:** Monitoring with AIDE to detect unauthorized changes
4. **Kernel:** Kernel-level protections against network attacks
5. **AppArmor:** Mandatory access control to limit process scope
6. **Software update mechanism:** Automated security package updates