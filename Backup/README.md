# Backup Architecture and Procedures

This document provides a unified overview of backup strategies, encryption policies, storage procedures, and recovery operations for all critical infrastructure components.

---

## 1. AAA Server (VM1)

**Components:** FreeRADIUS, Firewall, Hardening, MariaDB

### **Backup Method**

* Weekly full backup (Mondays 02:00)
* Daily incremental backup (02:00)
* Monthly offline export (every 1st of the month)

### **Storage**

* Internal backup server using RAID and rsync
* Monthly encrypted off-site disk (GFS rotation)

### **Security**

* Encrypted backups (GPG per-file)
* Transfers via SSH
* Integrity checks, restoration tests
* Minimum‑privilege accounts

### **Recovery Procedure**

1. Select appropriate backup (daily or full)
2. Decrypt using GPG
3. Restore DB and config files
4. Restart AAA services
5. Validate logs, authentication, and system behavior

---

## 2. Web Server (VM4)

**Components:** Nginx, PHP, Web App, Firewall, Hardening

### **Backup Method**

* Weekly full backup (Monday 02:00)
* Daily differential backup (02:00)

### **Storage**

* Central remote backup server
* Offline monthly backup (DVD/NAS)

### **Security**

* Transfers via SSH/SCP
* Encrypted storage (GPG)
* Special protection for SSL certificates

### **Recovery Procedure**

1. Choose backup based on incident impact
2. Decrypt with GPG
3. Restore configuration, code, and database
4. Restart services
5. Validate application functionality and logs

---

## 3. Certification Authority (CA)

**Highly critical: root key, certificates, CRL**

### **Backup Method**

* Full backup after every certificate issuance/revocation
* At minimum weekly

### **Storage**

* Encrypted internal server backup
* Encrypted offline USB/drive stored in a safe (3-2-1 compliance)

### **Security**

* AES‑256/GPG encryption
* Network access extremely restricted
* Strict physical security for offline copies

### **Recovery Procedure**

1. Decrypt in isolated environment
2. Restore private key, root certificate, PKI directory
3. Issue test certificate to validate

**If CA is compromised → rebuild CA; do NOT restore.**

---

## 4. Switches

**Object:** Full running/startup configuration

### **Backup Method**

* Daily automatic full config backup (02:00)
* Optionally triggered after each config change

### **Storage**

* Central repository structured by device and date
* Local startup-config as emergency fallback

### **Security**

* SCP/SFTP transfer
* Config secrets obfuscated when possible
* Daily checksum comparisons and alerts

### **Recovery Procedure**

1. Select latest valid configuration
2. Decrypt if required
3. Restore via console/TFTP/SFTP
4. Validate VLANs, routing, AAA, and logs

---

# Backup Matrix

| System         | Daily Backup (02:00)      | Weekly Backup (Mon 02:00) | Monthly Backup (Day 1 02:00) | Storage                                   | Encryption   |
| -------------- | ------------------------- | ------------------------- | ---------------------------- | ----------------------------------------- | ------------ |
| **AAA Server** | Incremental               | Full                      | Full (offline)               | Internal server + offline disk            | GPG          |
| **Web Server** | Differential              | Full                      | Full (offline)               | Internal server + remote repo + offline   | GPG          |
| **Routers**    | -                         | -                         | Full backup                  | Internal server + offline disk            | External GPG |
| **CA**         | CRL + issued cert updates | Full PKI backup           | Full                         | Internal + highly secured offline storage | GPG          |

---

# Files and Paths to Backup

## AAA Server

### FreeRADIUS

* `/etc/freeradius/clients.conf`
* `/etc/freeradius/mods-enabled/*`
* `/etc/freeradius/sites-enabled/*`

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

### MariaDB

**Config:**

* `/etc/mysql/mariadb.conf.d/50-server.cnf`
* `/etc/mysql/ssl/*`

**Data:**

* `/mnt/mysql_data/` or `containers/data/mariadb/`

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

## Routers (Mikrotik)

* `export file=router_backup.rsc`
* `/user ssh-keys private/`

---

## Certification Authority

* `ca-key.pem`
* `ca-cert.pem`
* `server-cert.pem`, `client-cert.pem`
* CRL, serial files, `index.txt`
