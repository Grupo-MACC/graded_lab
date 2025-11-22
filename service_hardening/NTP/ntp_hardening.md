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
systemctl start ntpsec
systemctl status ntpsec
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
restrict 10.0.2.0 mask 255.255.255.0 nomodify notrap noquery
restrict 127.0.0.1

disable monitor

# Local fallback clock
server 127.127.1.0
fudge 127.127.1.0 stratum 10

# Bind only trusted interfaces
interface ignore wildcard
interface ignore ipv6
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
Create logs directory
```bash
mkdir -p /var/log/ntpsec
chown ntpsec:ntpsec /var/log/ntpsec
chmod 700 /var/log/ntpsec
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
### 3.1 Edit the NTPsec configuration:
Edit /etc/ntpsec/ntp.conf:
```bash
nano /etc/ntpsec/ntp.conf
```
Paste the hardened server configuration (example below):
```ini
# /etc/ntpsec/ntp.conf, configuration for ntpd; see ntp.conf(5) for help

driftfile /var/lib/ntpsec/ntp.drift
leapfile /usr/share/zoneinfo/leap-seconds.list

# To enable Network Time Security support as a server, obtain a certificate
# (e.g. with Let's Encrypt), configure the paths below, and uncomment:
# nts cert CERT_FILE
# nts key KEY_FILE
# nts enable

# You must create /var/log/ntpsec (owned by ntpsec:ntpsec) to enable logging.
#statsdir /var/log/ntpsec/
#statistics loopstats peerstats clockstats
#filegen loopstats file loopstats type day enable
#filegen peerstats file peerstats type day enable
#filegen clockstats file clockstats type day enable

# This should be maxclock 7, but the pool entries count towards maxclock.
tos maxclock 11

# Comment this out if you have a refclock and want it to be able to discipline
# the clock by itself (e.g. if the system is not connected to the network).
tos minclock 4 minsane 3

# Specify one or more NTP servers.

# Public NTP servers supporting Network Time Security:
# server time.cloudflare.com nts

# pool.ntp.org maps to about 1000 low-stratum NTP servers.  Your server will
# pick a different set every time it starts up.  Please consider joining the
# pool: <https://www.pool.ntp.org/join.html>
server 192.168.1.1 iburst prefer

# Access control configuration; see /usr/share/doc/ntpsec-doc/html/accopt.html
# for details.
#
# Note that "restrict" applies to both servers and clients, so a configuration
# that might be intended to block requests from certain clients could also end
# up blocking replies from your own upstream servers.

# By default, exchange time with everybody, but don't allow configuration.
restrict default kod nomodify notrap nopeer noquery

restrict 127.0.0.1 nomodify notrap nopeer
restrict ::1

interface ignore wildcard
interface ignore ipv6
interface listen lo
interface listen enp0s3
```
Create logs directory
```bash
mkdir -p /var/log/ntpsec
chown ntpsec:ntpsec /var/log/ntpsec
chmod 700 /var/log/ntpsec
```
Restart NTPsec to apply:
```bash
systemctl restart ntpsec
systemctl status ntpsec
```
### 3.2 Enable NTPsec to start after the network is up
Create a systemd override so that ntpsec starts after the network is online:
```bash
systemctl edit ntpsec
```
Add the following
```bash
[Unit]
After=network-online.target
Wants=network-online.target
```
Then reload systemd and enable the service:
```bash
systemctl daemon-reexec
systemctl enable ntpsec
systemctl start ntpsec
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

## 5. Verify NTP Synchronization on Debian VM
Once the NTP server and clients are configured, verify that clients are correctly syncing with the AAA server.
### 5.1 Check NTP Status on the Client
On each Debian client, run:
```bash
# Check NTPsec daemon status
systemctl status ntpsec

# Check peers and synchronization status
ntpq -p
```
Expected output:
```markdown
     remote           refid      st t when poll reach   delay   offset  jitter
==========================================================================
+192.168.1.1       .AAA.         2 u   10   64   377   0.123   0.045   0.010
```
