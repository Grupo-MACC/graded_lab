#!/bin/bash

set -e

# Log
echo "===== Safe upgrade started: $(date) =====" >> /var/log/safe-upgrade.log

# 1. Actualizar índices
apt update -y >> /var/log/safe-upgrade.log 2>&1

# 2. Realizar upgrade seguro (NO dist-upgrade)
apt upgrade -y >> /var/log/safe-upgrade.log 2>&1

# 3. Recargar servicios sin interrumpir conexiones
systemctl reload nginx 2>/dev/null || true
systemctl reload mariadb 2>/dev/null || true
systemctl reload php*-fpm.service 2>/dev/null || true

echo "===== Safe upgrade finished: $(date) =====" >> /var/log/safe-upgrade.log
