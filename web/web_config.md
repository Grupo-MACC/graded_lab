# Despliegue de la aplicación `airport_web` en Linux con Nginx, PHP y MariaDB

Este documento describe los pasos para instalar, configurar y desplegar la aplicación web `airport_web` en un servidor Linux, configurando Nginx, PHP-FPM y MariaDB, y comprobando su funcionamiento desde la propia máquina y desde un router MikroTik.

---

## 1. Transferir el archivo de la aplicación al servidor

Desde tu máquina local, usamos `scp` para copiar el archivo comprimido al servidor remoto:

```bash
scp -P 2201 "Downloads/airport_web.zip" admin@localhost:/
```

Conectamos al servidor vía SSH:

```bash
ssh -p 2201 admin@localhost
```

Luego nos conectamos desde el router al servidor web:

```bash
system ssh address=192.168.10.2 user=user
su -
```

---

## 2. Copiar el archivo al servidor web y descomprimirlo

```bash
scp admin@192.168.1.2:/airport_web.zip ./
mkdir /var/www/web
mv airport_web.zip /var/www/web/airport_web.zip
cd /var/www/web
unzip airport_web.zip
```

---

## 3. Instalar Nginx y PHP

```bash
apt update
apt install nginx -y
apt install php php-fpm php-mysql php-cli php-common -y
```

---

## 4. Configurar Nginx para la aplicación

```bash
nano /etc/nginx/sites-available/web
```

Contenido(la version de php* puede variar):

```nginx
server {
    listen 80;
    server_name _;

    root /var/www/web/airport_web;
    index index.php index.html index.htm;

    access_log /var/log/nginx/web.access.log;
    error_log /var/log/nginx/web.error.log;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

Activamos el sitio y recargamos Nginx:

```bash
ln -s /etc/nginx/sites-available/web /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
ls -l /etc/nginx/sites-enabled/
```

---

## 5. Instalar y configurar MariaDB

```bash
apt install mariadb-server -y
systemctl enable mariadb
systemctl start mariadb
```

Conectamos como root:

```bash
mysql -u root
```

Dentro de MariaDB:

```sql
CREATE DATABASE flights;
USE flights;
SOURCE /var/www/web/airport_web/dump.sql;
CREATE USER 'webuser'@'localhost' IDENTIFIED BY 'webpass';
GRANT ALL PRIVILEGES ON flights.* TO 'webuser'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

---

## 6. Configurar conexión PHP a MariaDB

```bash
nano /var/www/web/airport_web/db_connection.php
```

Cambiar el usuario en el codigo a un usuario dedicado
```php
$dbuser = "webuser";
$dbpass = "webpass";
```

---

## 7. Reiniciar servicios

```bash
systemctl restart php8.2-fpm
systemctl restart nginx
```

---

## 8. Verificar funcionamiento

Desde la propia máquina web:

```bash
curl http://localhost
```

Desde el router MikroTik (RouterOS):

```rsc
/tool fetch url="http://192.168.10.2"
[admin@NAC] > /tool fetch url="https://192.168.10.2:8443" 
    status: finished
    downloaded: 2KiBC-z pause
    duration: 1s
```

Comprobar recursos estáticos:

```rsc
/tool fetch url="http://192.168.10.2/css/css.css" keep-result=no
/tool fetch url="http://192.168.10.2/connections.mp4" keep-result=no
```

---

## ✅ Resumen

* Se transfirió y descomprimió la aplicación.
* Se instaló y configuró Nginx y PHP-FPM.
* Se instaló MariaDB, se creó la base y usuario, y se importó el dump.
* Se configuró la conexión PHP a la base de datos.
* Se reiniciaron servicios y se verificó que la web es accesible desde el servidor y desde RouterOS.
