# Backup Architecture and Procedures

This document provides a unified overview of backup strategies, encryption policies, storage procedures, and recovery operations for all critical infrastructure components.

---

## 1. AAA Server (VM1)

**Components:** FreeRADIUS (container), Firewall, Hardening, MariaDB (container)

### Backup Method

* Weekly full backup (Mondays 02:00)
* Daily incremental backup (02:00)
* Monthly offline export (every 1st of the month)

### Storage

* Internal backup server using RAID and rsync
* Monthly encrypted off-site disk (GFS rotation)

### Security

* Encrypted backups (GPG per file)
* Transfers via SSH
* Integrity checks and periodic restore tests
* Least-privilege backup and restore accounts

### Recovery Procedure

1. Select the appropriate backup set (daily incremental or weekly full).
2. Decrypt backup files using GPG.
3. Restore database and configuration files.
4. Restart AAA services (FreeRADIUS container, MariaDB container, firewall).
5. Validate logs, RADIUS authentication, and overall system behavior.

---

## 2. Web Server (VM4)

**Components:** Nginx, PHP, Web Application, Firewall, Hardening

### Backup Method

* Weekly full backup (Mondays 02:00)
* Daily differential backup (02:00)

### Storage

* Central remote backup server
* Offline monthly backup (DVD/NAS or USB)

### Security

* Transfers via SSH/SCP
* Encrypted storage using GPG
* Additional protection for SSL private keys and certificates

### Recovery Procedure

1. Choose the correct backup (depending on the incident date and impact).
2. Decrypt backup with GPG.
3. Restore configuration files and web application code.
4. Restart Nginx, PHP-FPM and dependent services.
5. Validate web application functionality, logs, and HTTPS connectivity.

---

## 3. Certification Authority (CA)

**Highly critical assets: root key, certificates, CRL**

### Backup Method

* Full backup after every certificate issuance or revocation
* At minimum once per week

### Storage

* Encrypted internal server backup
* Encrypted offline USB/drive stored in a physical safe (3-2-1 rule)

### Security

* AES-256 / GPG encryption
* Extremely restricted network access to the CA
* Strict physical security for offline copies

### Recovery Procedure

1. Decrypt backup in an isolated environment.
2. Restore private key, root certificate, and complete PKI directory structure.
3. Issue a test certificate and verify CRL publication.

**If the CA is compromised → rebuild the CA from scratch; do NOT restore from backup.**

---

## 4. Switches

**Object:** Full running/startup configuration of each switch

### Backup Method

* Daily automatic full configuration backup (02:00)
* Optional on-demand backup after each configuration change

### Storage

* Central repository organized by device and date
* Local startup-config on the switch as emergency fallback

### Security

* SCP/SFTP transfers
* Configuration secrets obfuscated when possible
* Daily checksum comparison and alerting on changes

### Recovery Procedure

1. Select the latest valid configuration file.
2. Decrypt if required.
3. Restore via console/TFTP/SFTP as appropriate.
4. Validate VLANs, routing, AAA configuration, and logs.

---

## 5. Web_DB Server (extra VM)

**Components:** MariaDB (database for the web application)

### Backup Method

* Weekly full backup (Mondays 02:00)
* Daily incremental backup (02:00)
* Monthly offline export (logical dump of the application database)

### Storage

* Internal backup server
* Encrypted offline copies (USB/NAS)

### Security

* GPG encryption for database dumps and data directory
* SSH/SCP for all remote transfers
* Restricted database and system accounts for backup operations

### Recovery Procedure

1. Select the relevant full backup and required incrementals.
2. Decrypt backup files with GPG.
3. Restore MariaDB configuration and the data directory.
4. Start MariaDB and check service status.
5. Validate table integrity and connectivity from the Web Server.

---

# Backup Matrix

| System          | Daily Backup (02:00)      | Weekly Backup (Mon 02:00) | Monthly Backup (Day 1 02:00) | Storage                                   | Encryption |
| --------------- | ------------------------- | ------------------------- | ---------------------------- | ----------------------------------------- | ---------- |
| **AAA Server**  | Incremental               | Full                      | Full (offline)               | Internal server + offline disk            | GPG        |
| **Web Server**  | Differential              | Full                      | Full (offline)               | Internal server + remote repo + offline   | GPG        |
| **Web_DB**      | Incremental               | Full                      | Full (offline)               | Internal server + offline disk            | GPG        |
| **Switches**    | –                         | –                         | Full configuration backup    | Internal server + offline disk            | External GPG |
| **CA**          | CRL + issued cert updates | Full PKI backup           | Full                         | Internal + highly secured offline storage | GPG        |

---

# Files and Paths to Backup

## AAA Server

### FreeRADIUS (container)

Configuration inside `~/containers/config/freeradius`:

* `/home/user/containers/config/freeradius/clients.conf`
* `/home/user/containers/config/freeradius/default`
* `/home/user/containers/config/freeradius/inner-tunnel`
* `/home/user/containers/config/freeradius/sql/` (entire directory)

### Firewall

* `/root/aaa_firewall.sh`
* `/etc/iptables/rules.v4`
* `/etc/arptables.rules`

### System Hardening

* `/etc/sysctl.d/kernel-security.conf`
* `/etc/modprobe.d/securityclass.conf`
* `/etc/ssh/sshd_config*`
* `/etc/aide/aide.conf`, `/var/lib/aide/aide.db`
* `/etc/apparmor.d/*`
* `/etc/ntpsec/ntp.conf`
* `/usr/local/sbin/safe-upgrade.sh`

### MariaDB (container)

**Config:**

* `/home/user/containers/config/mariadb/custom.cnf`
* `/home/user/containers/config/mariadb/schema.sql`

**Data:**

* `/home/user/containers/data/mariadb/` (entire directory)

### Container design (Dockerfile)

* `/home/user/containers/design/freeradius/Dockerfile`

---

## Web Server

### Nginx + PHP

* `/etc/nginx/sites-available/web`
* `/etc/nginx/sites-enabled/web`
* `/etc/ssl/certs/nginx-selfsigned.crt`
* `/etc/ssl/private/nginx-selfsigned.key`
* `/etc/ssl/certs/dhparam.pem`
* `/var/www/web/airport_web/`
* `/etc/php/*`

### Firewall

* `/root/web_firewall.sh`
* `/etc/iptables/rules.v4`

### Hardening

* `/etc/sysctl.d/hardening.conf`
* `/etc/modprobe.d/securityclass.conf`
* `/etc/ssh/sshd_config`
* `/etc/aide/aide.conf`
* `/etc/apparmor.d/*`
* `/etc/ntpsec/ntp.conf`
* `/usr/local/sbin/safe-upgrade.sh`

---

## Web_DB Server

### MariaDB

**Config:**

* `/etc/mysql/mariadb.conf.d/50-server.cnf`
* Any additional customized files in `/etc/mysql/*.cnf`

**Data:**

* `/mnt/mysql_data/` (entire directory used for MariaDB data)

---

## Switches (Mikrotik)

* Configuration export: `export file=router_backup.rsc`
* SSH keys:
  * `/user ssh-keys private/`

---

## Certification Authority

* `ca-key.pem`
* `ca-cert.pem`
* `server-cert.pem`, `client-cert.pem`
* CRL, serial files, `index.txt`

---

## Common files on all servers

These files are backed up on all relevant machines (AAA, Web, Web_DB, Backup server, etc.):

* `/etc/ntpsec/ntp.conf`
* `/etc/ssh/sshd_config`
-----
# SCRIPTS/BACKUPS/BACKUPS_FULL.SH
#!/bin/bash

# === Carpetas de destino ===
FECHA="$(date +%F)"
DEST="/backups/full/${FECHA3}"
mkdir -p "$DEST"

# === Bases de datos ===
DB_USER="radius"
DB_PASS="radpass"
DB_NAME="radius"

echo "[*] Sacando dump de la base de datos..."
docker exec mariadb mariadb-dump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "${DEST}/radius.sql"

# === Configuraciones importantes ===
echo "[*] Copiando configuraciones..."
rsync -a /etc/ "${DEST}/etc/"
rsync -a /home/user/containers/config/freeradius/ "${DEST}/freeradius/"
rsync -a /etc/mysql/ "${DEST}/mysql/"
rsync -a /var/log/ "${DEST}/logs/"

echo "[OK] Backup FULL completado en ${DEST3}"
