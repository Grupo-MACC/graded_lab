## 1. Configuración de Usuarios y Shells

### Restricción de Shells
Todos los usuarios deben tener `nologin` como shell, excepto el usuario principal con acceso SSH.

**Verificación:**
```bash
cat /etc/passwd
```

**Cambiar shell a nologin:**
```bash
usermod -s /usr/sbin/nologin usuario
```

**Configurar bash restringido para el usuario principal:**
```bash
usermod -s /bin/rbash user
```
Esto obliga al usuario a escalar privilegios para realizar operaciones administrativas.

### Instalación y configuración de sudo
```bash
apt update && apt install -y sudo
cat /etc/sudoers
```
Asegurarse de que solo esté configurado root, excepto en casos excepcionales.
