## 2. Prevención de Filesystems Vulnerables

Evitar la instalación de sistemas de archivos que pueden ser vectores de ataque.

**Crear archivo de configuración:**
```bash
nano /etc/modprobe.d/securityclass.conf
```

**Contenido del archivo:**
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