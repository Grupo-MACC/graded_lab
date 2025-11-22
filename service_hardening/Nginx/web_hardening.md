# Configuración de Nginx con SSL auto-firmado para `airport_web`

Este documento describe cómo configurar Nginx con SSL auto-firmado en el servidor que hospeda `airport_web`.

---

## 1. Crear directorios para certificados y establecer permisos

```bash
mkdir -p /etc/ssl/private
chmod 700 /etc/ssl/private
```

* `/etc/ssl/private` contendrá las claves privadas.
* `chmod 700` asegura que solo root puede acceder.

---

## 2. Crear certificado SSL auto-firmado

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
-keyout /etc/ssl/private/nginx-selfsigned.key \
-out /etc/ssl/certs/nginx-selfsigned.crt
```

* `-x509`: crea un certificado auto-firmado.
* `-nodes`: sin passphrase para que Nginx pueda leer la clave automáticamente.
* `-days 365`: válido por 1 año.

Ajustamos permisos:

```bash
chmod 600 /etc/ssl/private/nginx-selfsigned.key
chmod 644 /etc/ssl/certs/nginx-selfsigned.crt
```

* Clave privada: solo root puede leer.
* Certificado público: lectura para todos.

Generamos parámetros Diffie-Hellman (recomendado para seguridad adicional):

```bash
openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
```

---

## 3. Configurar Nginx para HTTPS

Editamos el archivo de configuración:

```bash
nano /etc/nginx/sites-available/web
```

Contenido actualizado:

```nginx
# Redirigir HTTP a HTTPS
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name _;

    root /var/www/web/airport_web;
    index index.php index.html index.htm;

    # Logs
    access_log /var/log/nginx/web.access.log;
    error_log /var/log/nginx/web.error.log;

    # Certificados SSL
    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;

    # Parámetros SSL recomendados
    ssl_dhparam /etc/ssl/certs/dhparam.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # Procesar archivos PHP vía PHP-FPM
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

---

## 4. Probar y reiniciar Nginx

```bash
nginx -t
systemctl restart nginx
systemctl reload nginx
```

* `nginx -t` verifica que la configuración es correcta.
* Reiniciar y recargar aplica los cambios.

---

## 5. Verificar funcionamiento

Desde la propia máquina:

```bash
curl -Lk https://localhost
```

* `-L`: sigue redirecciones.
* `-k`: ignora advertencias de certificado auto-firmado.

Desde la red (IP de servidor):

```bash
curl -LkI http://192.168.10.2
```

Ejemplo de respuesta:

```
HTTP/1.1 301 Moved Permanently
Server: nginx
Location: https://192.168.10.2/

HTTP/1.1 200 OK
Server: nginx
Content-Type: text/html; charset=UTF-8
```

Desde RouterOS (MikroTik):

```rsc
/tool fetch url="https://192.168.10.2" mode=https check-certificate=no
```

* `check-certificate=no`: permite usar certificados auto-firmados.
* `status: finished` indica que la web es accesible vía HTTPS.

---

## ✅ Resumen

* Se crearon certificados auto-firmados y parámetros DH.
* Se configuró Nginx para redirigir HTTP a HTTPS y servir PHP con SSL.
* Se verificó que la web funciona correctamente desde la máquina local y desde la red, incluyendo RouterOS.

```
```

# Hardening y Seguridad del Servidor Web con Nginx y Linux

Este documento complementa la configuración SSL previa e incluye medidas de **hardening del sistema operativo**, **protección de archivos**, **Fail2ban** y **ajustes de seguridad del kernel**.

---

## 1. Asegurar Permisos en Archivos del Sistema

### 1.1 Proteger Configuración de Nginx

Aseguramos que solo el usuario `root` pueda modificar la configuración.

```bash
chown -R root:root /etc/nginx
find /etc/nginx -type d -exec chmod 755 {} \;
find /etc/nginx -type f -exec chmod 644 {} \;
```

**Explicación:**

* Directorios: ejecutables y legibles (755)
* Archivos: solo root escribe; todos leen (644)

---

### 1.2 Proteger Archivos de la Web

Asignamos los archivos al usuario de servicio (`www-data`).

```bash
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;
```

*Si tu web está en `/var/www/web/airport_web`, reemplázalo en los comandos.*

---

## 2. Instalar Defensa Proactiva con Fail2ban

Fail2ban bloquea automáticamente IPs que presentan actividad sospechosa.

```bash
apt install fail2ban -y
systemctl enable fail2ban
systemctl start fail2ban
```

Opcional: editar configuración en `/etc/fail2ban/jail.local`.

---

## 3. Hardening del Kernel (sysctl)

Creamos archivo dedicado para endurecimiento del sistema.

```bash
nano /etc/sysctl.d/hardening.conf
```

Agregar:

```bash
# --- Hardening de Red ---
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
```

Aplicar cambios:

```bash
sysctl -p
```

---

## 4. Asegurar Clave Privada del Certificado SSL

```bash
chmod 400 /etc/ssl/private/nginx-selfsigned.key
```

La clave queda accesible solo para root.

---

## 5. Proteger el PID de Nginx

```bash
chown root:root /var/run/nginx.pid
chmod 644 /var/run/nginx.pid
```

Esto evita manipulaciones del proceso.

---

## ✅ Resumen

Medidas aplicadas:

* Permisos estrictos en `/etc/nginx` y archivos web.
* Fail2ban instalado y activo.
* Kernel reforzado con sysctl.
* Certificados SSL y PID protegidos.

Este hardening mejora la seguridad general del servidor web y reduce la superficie de ataque.
