## 6. Software update mechanism
### Install and configure unattended-upgrades
This updates the necessary packages for security

```bash
apt install unattended-upgrades
dpkg-reconfigure unattended-upgrades
nano /etc/apt/apt.conf.d/50unattended-upgrades
```
### Pegar lo siguiente
```bash
Unattended-Upgrade::Origins-Pattern {
        // Solo actualizaciones de seguridad — totalmente seguro
        "o=Ubuntu,a=${distro_codename}-security";
};

// No reiniciar automáticamente servicios ni el sistema
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
```
### Automatizar el proceso
```bash
crontab -e > 0 3 1 * * /usr/local/sbin/safe-upgrade.sh
nano /usr/local/sbin/safe-upgrade.sh #Pegar el archivo
chmod +x /usr/local/sbin/safe-upgrade.sh
```