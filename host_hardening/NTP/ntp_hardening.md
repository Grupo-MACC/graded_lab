# NTP Hardening Setup Guide (NTPsec)
This document explains how NTP is deployed and secured across the environment using NTPsec (ntpd).
The AAA VM acts as the internal NTP server, and all other hosts, including Debian VMs and Mikrotik routers, act as NTP clients.

## 1. Install NTPsec
```bash
su -
apt update
apt install ntp -y
```
Verify installation:
```bash
systemctl enable ntpsec-wait.service
systemctl start ntpd
systemctl status ntpd
```

## 2. Configure AAA as the NTP Server
Edit the NTPsec configuration:
```bash
nano /etc/ntpsec/ntp.conf
```

Paste the hardened server configuration (example below):
```ini
# Drift and leap second files
driftfile /var/lib/ntpsec/ntp.drift
leapfile /usr/share/zoneinfo/leap-seconds.list

# Upstream servers
server time.google.com iburst prefer
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst

# Access control
restrict default kod nomodify notrap nopeer noquery
restrict 192.168.1.0 mask 255.255.255.0 nomodify notrap noquery
restrict 192.168.10.0 mask 255.255.255.0 nomodify notrap noquery
restrict 10.1.1.0 mask 255.255.255.0 nomodify notrap noquery
restrict 10.1.2.0 mask 255.255.255.0 nomodify notrap noquery
restrict 127.0.0.1

disable monitor

# Local fallback clock
server 127.127.1.0
fudge 127.127.1.0 stratum 10

# Bind only trusted interfaces
interface ignore wildcard
interface listen enp0s3
interface listen lo

# Logging
statsdir /var/log/ntpsec
statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable
logfile /var/log/ntp.log
```
Restart NTPsec to apply:
```bash
systemctl restart ntpd
systemctl status ntpd
```
### Server hardening highlights

- Synchronizes only with trusted upstream servers.

- Internal networks are allowed to sync but cannot modify or query the server.

- Local clock fallback ensures operation without upstream connectivity.

- Logging is secure and restricted to ntpsec user.

- Interface binding prevents exposure to untrusted networks.

- Remote monitor mode is disabled to reduce attack surface.

## 3. Configure Debian Hosts as NTP Clients
Edit the NTPsec configuration:
```bash
nano /etc/ntpsec/ntp.conf
```
Paste the hardened server configuration (example below):
```ini
# Internal NTP server only
server 192.168.1.1 iburst

# Default restrictions
restrict default kod nomodify notrap nopeer noquery
restrict 127.0.0.1
```
### Client hardening highlights

- Synchronizes time only from AAA server.

- Clients cannot serve time or respond to queries.

- Prevents exposure to untrusted external NTP sources.

- Ensures stable behavior using NTPsec's internal polling and drift management.

## 4. Configure Mikrotik Router as NTP Client
On Mikrotik router:
```bash
/system ntp client set enabled=yes mode=unicast servers=192.168.1.1
/system ntp client print
```
- Ensures router synchronizes only from AAA.

- Prevents router from acting as NTP server.

- Keeps all devices in LAN aligned with the same time source.