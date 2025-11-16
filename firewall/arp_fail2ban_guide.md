## PHASE 4: ADVANCED PROTECTIONS

### Step 4.1: Protection Against ARP Spoofing

**Why needed in this topology?**
- Shared network segments (NAC network, DMZ)
- Critical servers could be impersonated
- Man-in-the-middle attacks possible

On each Debian server:
```bash
# Install arptables
sudo apt-get install arptables

# Configure static ARP entries for critical hosts
# On AAA Server:
sudo arp -s 192.168.1.1 <NAC_ROUTER_MAC>  # Gateway

# Enable kernel protection
sudo bash -c 'cat >> /etc/sysctl.conf << EOF
# ARP spoofing protection
net.ipv4.conf.all.arp_filter = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1
EOF'

sudo sysctl -p

# Configure arptables
sudo arptables -A INPUT --source-mac ! <GATEWAY_MAC> --source-ip 192.168.1.1 -j DROP
sudo arptables-save > /etc/arptables.rules
```

### Step 4.2: DDoS Protection

**Why critical for this topology?**
- Web server is Internet-facing
- Limited bandwidth between networks
- Service availability is crucial

#### On Web Server (Additional DDoS rules):
```bash
# SYN flood protection
sudo iptables -N syn_flood
sudo iptables -A INPUT -p tcp --syn -j syn_flood
sudo iptables -A syn_flood -m limit --limit 100/s --limit-burst 150 -j RETURN
sudo iptables -A syn_flood -j DROP

# Enable SYN cookies
echo "net.ipv4.tcp_syncookies = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

```

### Step 4.3: Brute Force Protection with Fail2ban

**Why needed?**
- Even with port knocking, services can be attacked once opened
- Automated attacks are common
- Need automatic response to attacks

On all Debian servers:
```bash
# Configure fail2ban
sudo nano /etc/fail2ban/jail.local
```

Add:
```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
ignoreip = 127.0.0.1/8 192.168.1.0/24  # Don't ban local network

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

```
Start fail2ban:
```bash
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
```


---




Version prelimilar han habido modificaciones hay que mirarlo bien (No implementar de momento)

# ARP Spoofing Protection + Fail2ban Guide (Final Version)

## 🔒 ARP Spoofing Protection (arptables + sysctl + static ARP)

---

## 1️⃣ Install arptables
```bash
sudo apt-get update
sudo apt-get install -y arptables
```

---

## 2️⃣ Configure static ARP entries (per server)

### 🔹 AAA Server (192.168.1.1)
```bash
sudo arp -s 192.168.1.2 <MAC_DEL_NAC_EN_RED_192.168.1.0>
```

### 🔹 Web Server (192.168.10.2)
```bash
sudo arp -s 192.168.10.1 <MAC_DEL_NAC_EN_DMZ>
```

### 🔹 Backup Server (10.0.2.5)
```bash
sudo arp -s 10.0.2.2 <MAC_DEL_ROUTER_VIRTUALBOX>
```

---

## 3️⃣ Enable ARP hardening in the kernel
```bash
sudo bash -c 'cat >> /etc/sysctl.conf << EOF

### ARP Spoofing Protection ###
net.ipv4.conf.all.arp_filter = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1
EOF'

sudo sysctl -p
```

---

## 4️⃣ arptables anti-spoofing rules

### 🔹 AAA Server
```bash
sudo arptables -A INPUT --source-ip 192.168.1.2 --source-mac ! <MAC_DEL_NAC_EN_ESA_RED> -j DROP
```

### 🔹 Web Server
```bash
sudo arptables -A INPUT --source-ip 192.168.10.1 --source-mac ! <MAC_DEL_NAC_EN_DMZ> -j DROP
```

### 🔹 Backup Server
```bash
sudo arptables -A INPUT --source-ip 10.0.2.2 --source-mac ! <MAC_VIRTUALBOX_GATEWAY> -j DROP
```

---

## 5️⃣ Save arptables rules persistently

```bash
sudo sh -c "arptables-save > /etc/arptables.rules"
```

Create systemd service:
```bash
sudo bash -c 'cat > /etc/systemd/system/arptables.service << EOF
[Unit]
Description=Restore ARP Tables
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/sbin/arptables-restore < /etc/arptables.rules

[Install]
WantedBy=multi-user.target
EOF'
```

Enable it:
```bash
sudo systemctl enable arptables
sudo systemctl start arptables
```

---

# 🛡️ FAIL2BAN — Brute Force Protection

## 1️⃣ Install Fail2ban
```bash
sudo apt-get install -y fail2ban
```

---

## 2️⃣ Configure `/etc/fail2ban/jail.local`

```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd
ignoreip = 127.0.0.1/8 192.168.1.0/24 192.168.10.0/24 10.0.2.0/24

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
```

---

## 3️⃣ Enable Fail2ban

```bash
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
```

---

## 4️⃣ Check Fail2ban status

```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

---

# 🧪 Security Validation Tests

## ARP Spoofing Test
```bash
arpspoof -i enp0s3 -t 192.168.1.1 192.168.1.2
sudo arptables -L -n -v
```

Should show **DROP counters increasing**.

---

## Fail2ban Test
```bash
for i in {1..5}; do ssh wrong@192.168.1.1; done
sudo fail2ban-client status sshd
```

Your IP should appear in **Banned IPs**.

---

# ✅ Document Ready for Delivery
Ask me if you want this also as **PDF**, **DOCX**, or integrated into a full deployment manual.
