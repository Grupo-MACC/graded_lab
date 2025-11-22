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
