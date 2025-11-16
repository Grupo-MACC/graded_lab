This file contains the concrete commands to harden a MariaDB/MySQL installation on Debian. Execute commands as root or with `sudo`.


This guide provides practical steps and recommendations to harden a MariaDB/MySQL installation on Debian. The goal is to reduce the attack surface, improve authentication, and enforce secure configuration practices.

--



## 0. Machine creation and configuration

Create Web_DB VM
```bash
VBoxManage createvm --name "Web_DB" --basefolder "/<path_to_virtualbox_vm>" --groups
"/Irakaskuntza/<year>/Infrastructure and Network Security" --ostype "Other_64" --register

VBoxManage modifyvm "Web_DB" --memory 2048 --cpus 2 --audio-enabled off


VBoxManage storagectl "Web_DB" --name PIIX4 --add IDE --controller PIIX4

VBoxManage storagectl "Web_DB" --name SATA --add SATA

VBoxManage storageattach "Web_DB" --storagectl SATA --port 0 --device 0 --type hdd --medium
"/<path_to_virtualbox_vm>/Irakaskuntza/<year>/Infrastructure and Network Security/Debian/Web_DB.vdi" #AAA.vdi clone

VBoxManage modifyvm "Web_DB" --nic1 intnet --cable-connected1 on --intnet1 "nacnet" --mac-address1
000000000701
```
Start Web_DB VM, change hostname, set IP and DNS
```bash
su -
```
Change hostname to webdb
```bash
nano /etc/hostname
```
...
webdb
...

Set IP to 192.168.1.3
```bash
nano /etc/hosts
```
...
192.168.1.3 webdb
...

Set network interfaces
```bash
nano /etc/network/interfaces
```
...
iface enp0s3 inet static
        address 192.168.1.3/24
        gateway 192.168.1.2
        dns-nameservers 192.168.1.2
...

Set DNS
```bash
nano /etc/resolv.conf
```
...
nameserver 192.168.1.2
...

```bash
sudo apt update
sudo apt upgrade -y
```

## 1. MariaDB installation
```bash
sudo apt install mariadb-server mariadb-client -y
```
See status
```bash
sudo systemctl status mariadb
```
Enable on startup
```bash
sudo systemctl enable mariadb
```
Start / Restart
```bash
sudo systemctl start mariadb
sudo systemctl restart mariadb
```

## 2. Basic secure installation

Run interactive secure setup:
```bash
sudo mysql_secure_installation
```
Enter current password for root (enter for none): [enter]

Switch to unix_socket authentication [Y/n] Y

Change the root password? [Y/n] n

Remove anonymous users? [Y/n] Y

Disallow root login remotely? [Y/n] Y

Remove test database and access to it? [Y/n] Y

Reload privilege tables now? [Y/n] Y

## 3. Operating System Level Configuration
### 3.1. Move datadir to a non-system partition (example: /mnt/mysql_data)
Stop service, copy data, set ownership and update config:
```bash
sudo systemctl stop mariadb
sudo mkdir -p /mnt/mysql_data
sudo rsync -av /var/lib/mysql/ /mnt/mysql_data/
sudo chown -R mysql:mysql /mnt/mysql_data
```
Edit data directory in config:
```bash
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
```
Change datadir to /mnt/mysql_data
Start and verify:
```bash
sudo systemctl start mariadb
sudo systemctl status mariadb
sudo mysql -e "SHOW VARIABLES LIKE 'datadir';"
```

### 3.2. Ensure dedicated, non-interactive mysql user
Create group/user (id optional) and set nologin shell, then own filesystem objects:
```bash
sudo groupadd -g 27 -o -r mysql 2>/dev/null || true
sudo useradd -M -N -g mysql -o -r -d /nonexistent -s /usr/sbin/nologin -c "MySQL Server" -u 27 mysql || true

sudo mkdir -p /var/log/mysql
sudo chmod 750 /var/log/mysql

sudo chown -R mysql:mysql /mnt/mysql_data
sudo chown -R mysql:mysql /etc/mysql
sudo chown -R mysql:mysql /var/log/mysql
```
Verify shell is disabled:
```bash
getent passwd mysql
sudo su - mysql || true
```

### 3.3. Systemd sandboxing for MariaDB (create override)
Create a systemd drop-in that tightens isolation, then reload and restart:
```bash
sudo systemctl edit mariadb.service
```
Copy this:
```bash
[Service]
ProtectSystem=full
ProtectHome=true
PrivateTmp=true

ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
NoNewPrivileges=true
ReadOnlyPaths=/
ReadWritePaths=/mnt/mysql_data /var/log/mysql /run/mysqld /etc/mysql/ssl

User=mysql
Group=mysql
```
Reload and restart:
```bash
sudo systemctl daemon-reload
sudo systemctl start mariadb
sudo systemctl status mariadb
```
Create a tmpfiles archive for MariaDB:
```bash
sudo nano /etc/tmpfiles.d/mariadb.conf
```
Add this line:
```ìni
d /run/mysqld 0755 mysql mysql -
```
Apply immediately:
```bash
sudo systemd-tmpfiles --create
```
Restart MariaDB:
```bash
sudo systemctl restart mariadb
sudo systemctl status mariadb
```

## 4. Installation and Planning
### 4.1. Implement Connection Delays to Limit Failed Login Attempts

Set a maximum number of connections globally and per user: (`/etc/mysql/mariadb.conf.d/50-server.cnf`):

```bash
[mysqld]
max_connections = 150
```

Per-user limit:
```sql
ALTER USER 'username'@'host' WITH MAX_USER_CONNECTIONS 10;
```

### 4.2. Unique Cryptographic Material
#### 4.2.1 Prepare Cryptographic Material
On your backup server, create a folder for MariaDB certificates:
```bash
mkdir -p ~/mariadb_certificates
cd ~/mariadb_certificates/
```
Generate the Certificate Authority (CA), the server certificate, and the client certificate:
```bash
# Generate CA key and certificate
openssl genrsa 2048 > ca-key.pem
openssl req -new -x509 -nodes -days 3650 \
  -key ca-key.pem -out ca-cert.pem -subj "/CN=MariaDB-CA"

# Generate server key and CSR
openssl genrsa 2048 > server-key.pem
openssl req -new -key server-key.pem -out server-req.pem -subj "/CN=MariaDB-Server"

# Sign the server certificate with the CA
openssl x509 -req -in server-req.pem -days 3650 \
  -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 -out server-cert.pem

# Generate client key and CSR
openssl genrsa 2048 > client-key.pem
openssl req -new -key client-key.pem -out client-req.pem -subj "/CN=MariaDB-Client"

# Sign the client certificate with the CA
openssl x509 -req -in client-req.pem -days 3650 \
  -CA ca-cert.pem -CAkey ca-key.pem -set_serial 02 -out client-cert.pem
```

#### 4.2.2 Prepare the MariaDB Server
Create a secure folder for SSL certificates:
```bash
sudo mkdir -p /etc/mysql/ssl
```

Transfer the files from the backup server to the NAC router:
Create a folder in NAC
```bash
file add type=directory name=MariaDB_certificates
```
Transfer the files to NAC router
```bash
scp * admin@10.0.2.4:/MariaDB_certificates/
```

In webdb using scp get the files:
```bash
mkdir certificates
scp admin@10.0.2.4:MariaDB_certificates/* /home/user/certificates/
```

Move the files into a mos secure folder:
```bash
sudo mv ~/certificates/* /etc/mysql/ssl/
```

#### 4.2.3 Set Permissions and Ownership
```bash
sudo chown -R mysql:mysql /etc/mysql/ssl
sudo chmod 600 /etc/mysql/ssl/*-key.pem
sudo chmod 644 /etc/mysql/ssl/*.pem
```

#### 4.2.4 Configure MariaDB to Use SSL
Edit the configuration file:
```bash
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
```
Add or adjust under [mysqld]:
```ìni
[mysqld]
ssl-ca=/etc/mysql/ssl/ca-cert.pem
ssl-cert=/etc/mysql/ssl/server-cert.pem
ssl-key=/etc/mysql/ssl/server-key.pem
```
Restart MariaDB:
```bash
sudo systemctl restart mariadb
sudo systemctl status mariadb
```

#### 4.2.5 Create a MariaDB User That Requires SSL
Log in as root and create a secure user requiring X509 certificates:
```sql
CREATE USER 'airport'@'localhost' REQUIRE X509;
GRANT ALL PRIVILEGES ON *.* TO 'airport'@'localhost' REQUIRE X509;
FLUSH PRIVILEGES;
```
Check SSL status:
```sql
SHOW SESSION STATUS LIKE 'Ssl_version';
```

#### 4.2.6 Test Connection Using Certificates
Log into MariaDB as airport user using certificates:
```bash
mysql -u airport \
  --ssl-ca=/etc/mysql/ssl/ca-cert.pem \
  --ssl-cert=/etc/mysql/ssl/client-cert.pem \
  --ssl-key=/etc/mysql/ssl/client-key.pem
```
Do not use a password: authentication is handled solely via certificates.

#### 4.2.7 Final Cleanup of Client Certificates
For security, do not leave client certificates on the server:
```bash
sudo rm /etc/mysql/ssl/client-*.pem
rm -r certificates
```
Client certificates should remain only on the systems that will connect to MariaDB, such as backup servers or authorized clients.

Drop the user used for the test:
```sql
DROP USER 'airport'@'localhost';
```

### 4.3 Production user and database creation
Edit the configuration file:
```bash
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
```
Change the bind-address value to 0.0.0.0
This makes tbe database accessible for any host

Upload the database dump to the NAC router
```bash
scp -P 2201 dump.sql admin@localhost:
```

Retrieve the dump on the webdb server
```bash
scp admin@10.0.2.4:dump.sql /home/user/
```

Create the database
```sql
CREATE DATABASE flights;
USE flights;
```

Import the structure and data
```sql
SOURCE /home/user/dump.sql;
```

Create a secure production user
```sql
CREATE USER 'webuser'@'192.168.10.2' REQUIRE X509;
```

Grant read-only access to the database
```sql
GRANT SELECT ON flights.* TO 'webuser'@'192.168.10.2' REQUIRE X509;
FLUSH PRIVILEGES;
```