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
Make executable:
```bash
chmod +x /usr/local/sbin/safe-upgrade.sh
```
