# COMPLETE STEP-BY-STEP SECURITY IMPLEMENTATION GUIDE
## Infrastructure and Network Security - Graded Lab



---

## 1. UNDERSTANDING YOUR NETWORK TOPOLOGY

### Your Network Architecture:
```

Internet (10.0.2.0/24)
    |
   ├── Backup Server (10.0.2.5) (Debian server)
    |
   └── NAC Router (10.0.2.4/24)
            |
           ├── NAC Network (192.168.1.0/24)
            |   ├── AAA Server (192.168.1.1/24)
            |   
            |
           └── Supplicant Network (10.1.1.0/24)
                └── Supplicant1 Router (10.1.1.2/24)
            └── DMZ Network (192.168.10.0/24)
                            └── Web Server (192.168.10.2/24)
```

### Why This Topology Matters for Security:
- **DMZ Isolation**: Web server is in DMZ, separated from internal networks
- **NAC Network**: Contains critical AAA infrastructure
- **Multiple Security Zones**: Each zone requires different protection levels
- **Choke Points**: Routers act as security enforcement points

---

## 2. SECURITY STRATEGY OVERVIEW

### Defense in Depth Principle:
We're implementing multiple layers of security:

1. **Perimeter Defense** (NAC Router): First line of defense
2. **Network Segmentation**: Isolate different zones
3. **Host-based Protection**: Individual server firewalls
4. **Access Control**: Port knocking for management
5. **Monitoring**: Logging and intrusion detection

### Why Each Component Needs Protection:

| Component | Role | Why It Needs Protection |
|-----------|------|------------------------|
| **AAA Server** | Authentication hub | Compromise = network-wide access |
| **Web Server** | Public-facing service | Internet exposure = high risk |
| **Backup Server** | Data storage | Contains sensitive backups |
| **NAC Router** | Main gateway | Controls all traffic flow |
| **Supplicant1 Router** | DMZ gateway | Bridges internal and DMZ |

---

## PHASE 1: PREPARE THE ENVIRONMENT

### Step 1.1: Start All VMs
```bash
# Start VMs in this order:
1. NAC Router (MikroTik)
2. Supplicant1 Router (MikroTik)
3. AAA Server (Debian)
4. Web Server (Debian)
5. Backup Server (Debian)
```

**Why this order?** Routers must be up first to provide network connectivity.

### Step 1.2: Verify Network Connectivity
AQUI AÑADE COMO VERIFICAMOS LA CONECTIVIDAD

**Why verify?** Ensure basic connectivity before applying security rules.

### Step 1.3: Install Required Software on Debian Nodes

Connect to each Debian server and run:
```bash
# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install security tools
sudo apt-get install -y \
    iptables \
    iptables-persistent \
    aide \
    arptables \
    rsyslog \
    net-tools \
    tcpdump
```

**Why these tools?**
- `iptables`: Main firewall
- `fail2ban`: Brute force protection
- `aide`: File integrity monitoring
- `arptables`: ARP attack protection

---

## PHASE 2: IMPLEMENT BASIC FIREWALL RULES

### Step 2.1: Configure AAA Server Firewall

SSH to AAA Server (192.168.1.10):
```bash
# Create firewall script
root@AAA:~# cat /root/aaa_firewall.sh
#!/bin/bash
# AAA Server Unified Hardened Firewall (Direct Port-Knocking)

# Variables
AAA_IP="192.168.1.1"
NAC_IP="192.168.1.2"
WEB_IP="192.168.10.2"
BACKUP_IP="10.0.2.5"

# Flush existing rules
iptables -F
iptables -X
iptables -Z

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Anti-spoofing
iptables -A INPUT -s 127.0.0.0/8 ! -i lo -j DROP
iptables -A INPUT -s $AAA_IP ! -i lo -j DROP

# Allow established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ===============================
#        ICMP (con límite)
# ===============================
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/s -j ACCEPT

# ===============================
#       ANTI-DDoS / SYN flood
# ===============================
iptables -N ANTI_DDOS
iptables -A INPUT -j ANTI_DDOS
iptables -A ANTI_DDOS -p tcp --syn -m limit --limit 100/s --limit-burst 150 -j RETURN
iptables -A ANTI_DDOS -j DROP

# ===============================
#   SSH DIRECTO DESDE NAC (fiable)
# ===============================
iptables -A INPUT -s $NAC_IP -p tcp --dport 22 -j ACCEPT

# ===============================
#         PORT-KNOCKING
#    (modelo directo del script 1)
# ===============================

# Knock 1
iptables -A INPUT -p tcp --dport 7000 -m recent --name KNOCK1 --set -j DROP

# Knock 2 (requiere knock 1)
iptables -A INPUT -p tcp --dport 8000 \
    -m recent --name KNOCK1 --rcheck --seconds 15 \
    -m recent --name KNOCK2 --set -j DROP

# Knock 3 (requiere knock 2)
iptables -A INPUT -p tcp --dport 9000 \
    -m recent --name KNOCK2 --rcheck --seconds 15 \
    -m recent --name KNOCK3 --set -j DROP

# SSH autorizado si se hicieron los 3 knocks en <30s
iptables -A INPUT -p tcp --dport 22 \
    -m recent --name KNOCK3 --update --seconds 30 --reap \
    -j ACCEPT

# Cleanup knocks
iptables -A INPUT -m recent --name KNOCK1 --remove
iptables -A INPUT -m recent --name KNOCK2 --remove
iptables -A INPUT -m recent --name KNOCK3 --remove

# ===============================
#              NTP
# ===============================
iptables -A INPUT -p udp --dport 123 -s 192.168.1.0/24 -m limit --limit 10/s -j ACCEPT
iptables -A INPUT -p udp --dport 123 -s 192.168.10.0/24 -m limit --limit 10/s -j ACCEPT

# ===============================
#             RADIUS
# ===============================
iptables -A INPUT -p udp --dport 1812 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p udp --dport 1813 -s 192.168.1.0/24 -j ACCEPT

# Red adicional del segundo script
iptables -A INPUT -p udp --dport 1812 -s 10.1.1.0/24 -j ACCEPT
iptables -A INPUT -p udp --dport 1813 -s 10.1.1.0/24 -j ACCEPT

# ===============================
#            SYSLOG
# ===============================
iptables -A INPUT -p udp --dport 514 -s $WEB_IP -j ACCEPT

# ===============================
#           OUTPUT RULES
# ===============================
iptables -A OUTPUT -d $BACKUP_IP -p tcp --dport 873 -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp --dport 123 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT

# ===============================
#            LOGGING
# ===============================
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "AAA-DROP: "

# DROP explícito final
iptables -A INPUT -j DROP

# Save rules
iptables-save > /etc/iptables/rules.v4

**Why these specific rules for AAA?**
- RADIUS ports only from NAC network (authentication source)
- No web ports (not a web server)
- Outbound backup allowed (data protection)
- DNS allowed (name resolution for logs)

### Step 2.2: Configure Web Server Firewall

SSH to Web Server (192.168.10.2):
```bash
# Create firewall script

root@Web:~# cat /root/web_firewall.sh
#!/bin/bash
# Web Server Unified Hardened Firewall (Direct Port-Knocking)

# Variables
WEB_IP="192.168.10.2"
AAA_IP="192.168.1.1"
BACKUP_IP="10.0.2.5"
DMZ_GW="192.168.10.1"

# ==================================================
# Flush
# ==================================================
iptables -F
iptables -X
iptables -Z

# ==================================================
# Default policies
# ==================================================
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# ==================================================
# Loopback
# ==================================================
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# ==================================================
# Established/related
# ==================================================
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ==================================================
# SSH directo desde DMZ gateway (gestión legítima)
# ==================================================
iptables -A INPUT -s $DMZ_GW -p tcp --dport 22 -j ACCEPT

# ==================================================
# DIRECT PORT-KNOCKING (modelo del primer firewall)
# ==================================================

# Knock 1
iptables -A INPUT -p tcp --dport 7000 -m recent --name KNOCK1 --set -j DROP

# Knock 2 (requiere knock 1)
iptables -A INPUT -p tcp --dport 8000 \
    -m recent --name KNOCK1 --rcheck --seconds 15 \
    -m recent --name KNOCK2 --set -j DROP

# Knock 3 (requiere knock 2)
iptables -A INPUT -p tcp --dport 9000 \
    -m recent --name KNOCK2 --rcheck --seconds 15 \
    -m recent --name KNOCK3 --set -j DROP

# SSH permitido si se completan los 3 knocks (<30s)
iptables -A INPUT -p tcp --dport 22 \
    -m recent --name KNOCK3 --update --seconds 30 --reap \
    -j ACCEPT

# Limpieza de knocks antiguos
iptables -A INPUT -m recent --name KNOCK1 --remove
iptables -A INPUT -m recent --name KNOCK2 --remove
iptables -A INPUT -m recent --name KNOCK3 --remove

# ==================================================
# ICMP limitado
# ==================================================
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/s -j ACCEPT

# ==================================================
# SYN flood protection
# ==================================================
iptables -N SYN_FLOOD
iptables -A INPUT -p tcp --syn -j SYN_FLOOD
iptables -A SYN_FLOOD -m limit --limit 100/s --limit-burst 150 -j RETURN
iptables -A SYN_FLOOD -j DROP

# ==================================================
# HTTP/HTTPS con protección avanzada
# ==================================================

# Límite de conexiones por IP (anti-abuso)
iptables -A INPUT -p tcp --dport 80  -m connlimit --connlimit-above 100 -j REJECT --reject-with tcp-reset
iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 100 -j REJECT --reject-with tcp-reset

# Rate-limit: máximo 20 conexiones nuevas por segundo por IP
iptables -A INPUT -p tcp --dport 80  -m recent --name HTTP  --update --seconds 1 --hitcount 20 -j DROP
iptables -A INPUT -p tcp --dport 80  -m recent --name HTTP  --set

iptables -A INPUT -p tcp --dport 443 -m recent --name HTTPS --update --seconds 1 --hitcount 20 -j DROP
iptables -A INPUT -p tcp --dport 443 -m recent --name HTTPS --set

# Permitir HTTP/HTTPS tras filtros
iptables -A INPUT -p tcp --dport 80  -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# ==================================================
# OUTGOING
# ==================================================
iptables -A OUTPUT -d $AAA_IP -p udp --dport 514 -j ACCEPT
iptables -A OUTPUT -d $AAA_IP -p udp --dport 123 -j ACCEPT
iptables -A OUTPUT -d $BACKUP_IP -p tcp --dport 873 -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# ==================================================
# Logging
# ==================================================
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "WEB-DROP: "

# Drop final explícito
iptables -A INPUT -j DROP

# ==================================================
# Save rules
# ==================================================
iptables-save > /etc/iptables/rules.v4
Execute:
```bash
sudo chmod +x /root/web_firewall.sh
sudo /root/web_firewall.sh
```

**Why these specific rules for Web?**
- HTTP/HTTPS open to all (public service)
- Connection limits (DDoS protection)
- Rate limiting (abuse prevention)
- Logs to AAA (centralized logging)

### Step 2.3: Configure Backup Server Firewall

SSH to Backup Server (10.0.2.4):
```bash
# Create firewall script


Execute:
```bash
sudo chmod +x /root/backup_firewall.sh
sudo /root/backup_firewall.sh
```
root@backup:~# cat /root/backup_firewall.sh
#!/bin/bash
# Backup Server Hardened Firewall (Direct Port-Knocking + DNS Fix)

# ==================================================
# Flush
# ==================================================
iptables -F
iptables -X
iptables -Z

# ==================================================
# Policies
# ==================================================
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# ==================================================
# Loopback
# ==================================================
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# ==================================================
# Established / Related
# ==================================================
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ==================================================
# DNS Response Fix (UDP/TCP src port 53)
# ==================================================
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A INPUT -p tcp --sport 53 -j ACCEPT

# ==================================================
# ICMP (solo NAT INTERNAL)
# ==================================================
iptables -A INPUT -p icmp -s 10.0.2.0/24 -j ACCEPT

# ==================================================
# PORT KNOCKING (direct mode)
# ==================================================

# Knock 1
iptables -A INPUT -p tcp --dport 7000 \
    -m recent --name KNOCK1 --set -j DROP

# Knock 2
iptables -A INPUT -p tcp --dport 8000 \
    -m recent --name KNOCK1 --rcheck --seconds 15 \
    -m recent --name KNOCK2 --set -j DROP

# Knock 3
iptables -A INPUT -p tcp --dport 9000 \
    -m recent --name KNOCK2 --rcheck --seconds 15 \
    -m recent --name KNOCK3 --set -j DROP

# Allow SSH after knock sequence (<30s)
iptables -A INPUT -p tcp --dport 22 \
    -m recent --name KNOCK3 --update --seconds 30 --reap \
    -j ACCEPT

# Cleanup stale knocks
iptables -A INPUT -m recent --name KNOCK1 --remove
iptables -A INPUT -m recent --name KNOCK2 --remove
iptables -A INPUT -m recent --name KNOCK3 --remove

# ==================================================
# RSYNC (873/tcp) only from AAA + Web
# ==================================================
iptables -A INPUT -p tcp --dport 873 -s 192.168.1.1 -j ACCEPT
iptables -A INPUT -p tcp --dport 873 -s 192.168.10.2 -j ACCEPT

# Limit simultaneous backup connections
iptables -A INPUT -p tcp --dport 873 -m connlimit --connlimit-above 10 -j REJECT

# ==================================================
# OUTPUT rules
# ==================================================
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

iptables -A OUTPUT -p udp --dport 123 -j ACCEPT

iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# ==================================================
# Logging
# ==================================================
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "BKP-DROP: "

# ==================================================
# Save rules
# ==================================================
iptables-save > /etc/iptables/rules.v4

**Why these specific rules for Backup?**
- Rsync only from AAA and Web (authorized backup sources)
- No other services (dedicated backup server)
- Connection limits (prevent resource exhaustion)

---

## PHASE 3: FIREWALL NAC

[admin@NAC] /ip/firewall/filter> print
Flags: X - disabled, I - invalid; D - dynamic
 0    ;;; INPUT: Allow established/related
      chain=input action=accept connection-state=established,related

 1    ;;; INPUT: Drop invalid
      chain=input action=drop connection-state=invalid

 2    ;;; INPUT: Allow loopback
      chain=input action=accept in-interface=lo

 3    ;;; INPUT: Allow ICMP from NAC network
      chain=input action=accept protocol=icmp src-address=192.168.1.0/24

 4    ;;; INPUT: Allow ICMP from NAT network
      chain=input action=accept protocol=icmp src-address=10.0.2.0/24

 5    ;;; INPUT: Allow ICMP from DMZ network
      chain=input action=accept protocol=icmp src-address=192.168.10.0/24

 6    ;;; INPUT: SSH from MGMT (Windows NAT)
      chain=input action=accept protocol=tcp src-address-list=MGMT dst-port=22

 7    ;;; INPUT: WinBox from MGMT (Windows NAT)
      chain=input action=accept protocol=tcp src-address-list=MGMT dst-port=8291

 8    ;;; INPUT: Port knock stage 1
      chain=input action=add-src-to-address-list protocol=tcp address-list=knock_stage1 address-list-timeout=15s dst-port=1111

 9    ;;; INPUT: Port knock stage 2
      chain=input action=add-src-to-address-list protocol=tcp src-address-list=knock_stage1 address-list=knock_stage2 address-list-timeout=15s dst-port=2222

10    ;;; INPUT: Port knock stage 3 (access granted)
      chain=input action=add-src-to-address-list protocol=tcp src-address-list=knock_stage2 address-list=knock_stage3 address-list-timeout=10m dst-port=3333

11    ;;; INPUT: SSH after knocking
      chain=input action=accept protocol=tcp src-address-list=knock_stage3 dst-port=22

12    ;;; INPUT: WinBox after knocking
      chain=input action=accept protocol=tcp src-address-list=knock_stage3 dst-port=8291

13    ;;; INPUT: Log SSH without knock
      chain=input action=log protocol=tcp src-address-list=!knock_stage3 dst-port=22 log-prefix="SSH-NO-KNOCK:"

14    ;;; INPUT: Drop SSH without knock
      chain=input action=drop protocol=tcp src-address-list=!knock_stage3 dst-port=22

15    ;;; INPUT: Drop WinBox without knock
      chain=input action=drop protocol=tcp src-address-list=!knock_stage3 dst-port=8291

16    ;;; INPUT: Drop FIN scan
      chain=input action=drop tcp-flags=fin,!syn,!rst,!psh,!ack,!urg protocol=tcp

17    ;;; INPUT: Drop SYN-RST scan
      chain=input action=drop tcp-flags=syn,rst protocol=tcp

18    ;;; INPUT: Drop SYN-FIN scan
      chain=input action=drop tcp-flags=fin,syn protocol=tcp

19    ;;; INPUT: Log dropped input
      chain=input action=log limit=1,10:packet log-prefix="INPUT-DROP:"

20    ;;; INPUT: Drop all other input
      chain=input action=drop

21    ;;; FORWARD: Allow established/related
      chain=forward action=accept connection-state=established,related

22    ;;; FORWARD: Drop invalid
      chain=forward action=drop connection-state=invalid

23    ;;; FORWARD: Limit HTTP conn per IP to Web
      chain=forward action=drop connection-limit=50,32 protocol=tcp dst-address=192.168.10.2 dst-port=80

24    ;;; FORWARD: Limit HTTPS conn per IP to Web
      chain=forward action=drop connection-limit=50,32 protocol=tcp dst-address=192.168.10.2 dst-port=443

25    ;;; FORWARD: Allow DMZ to Internet
      chain=forward action=accept src-address=192.168.10.0/24 dst-address=!192.168.0.0/16

26    ;;; FORWARD: Allow DMZ to NAC network
      chain=forward action=accept src-address=192.168.10.0/24 dst-address=192.168.1.0/24

27    ;;; FORWARD: Allow NAC to Internet
      chain=forward action=accept src-address=192.168.1.0/24 dst-address=!192.168.0.0/16

28    ;;; FORWARD: Allow NAC to DMZ network
      chain=forward action=accept src-address=192.168.1.0/24 dst-address=192.168.10.0/24

29    ;;; FORWARD: SYN flood accept under limit
      chain=forward action=accept tcp-flags=syn connection-limit=500,32 protocol=tcp

30    ;;; FORWARD: SYN flood drop excess
      chain=forward action=drop tcp-flags=syn protocol=tcp

31    ;;; FORWARD: Log dropped forward
      chain=forward action=log limit=1,10:packet log-prefix="FWD-DROP:"

32    ;;; FORWARD: Drop all other forward
      chain=forward action=drop

[admin@NAC] /ip/firewall/filter> ..
[admin@NAC] /ip/firewall> nat
[admin@NAC] /ip/firewall/nat> remove [find]
[admin@NAC] /ip/firewall/nat> add chain=srcnat action=masquerade src-address=192.168.1.0/24  out-interface=ether1 comment="NAT: NAC network to Internet"
[admin@NAC] /ip/firewall/nat> add chain=srcnat action=masquerade src-address=192.168.10.0/24 out-interface=ether1 comment="NAT: DMZ network to Internet"
[admin@NAC] /ip/firewall/nat> add chain=srcnat action=masquerade src-address=10.0.2.0/24 out-interface=ether1 comment="NAT: NAT network to Internet (VirtualBox)"
[admin@NAC] /ip/firewall/nat> print
Flags: X - disabled, I - invalid; D - dynamic
 0    ;;; NAT: NAC network to Internet
      chain=srcnat action=masquerade src-address=192.168.1.0/24 out-interface=ether1

 1    ;;; NAT: DMZ network to Internet
      chain=srcnat action=masquerade src-address=192.168.10.0/24 out-interface=ether1

 2    ;;; NAT: NAT network to Internet (VirtualBox)
      chain=srcnat action=masquerade src-address=10.0.2.0/24 out-interface=ether1



### Test 1: Basic Connectivity
```bash
# From AAA server
ping 192.168.1.1        # Should work (gateway)
ping 192.168.10.2       # Should fail (different network, no route)
curl http://192.168.10.2  # Should fail (firewall blocks)

# From Web server
curl http://www.google.com  # Should work (Internet access)
```

### Test 2: Port Knocking
# Secuencia openSSH: 7000, 8000, 9000
(New-Object System.Net.Sockets.TcpClient).Connect("localhost", 7000)
Start-Sleep -Milliseconds 500
(New-Object System.Net.Sockets.TcpClient).Connect("localhost", 8000)
Start-Sleep -Milliseconds 500
(New-Object System.Net.Sockets.TcpClient).Connect("localhost", 9000)
Start-Sleep -Seconds 2

# Ahora SSH
ssh -p 2202 user@localhost




# Hacer knock
(New-Object System.Net.Sockets.TcpClient).Connect("localhost", 1111)
Start-Sleep -Milliseconds 500
(New-Object System.Net.Sockets.TcpClient).Connect("localhost", 2222)
Start-Sleep -Milliseconds 500
(New-Object System.Net.Sockets.TcpClient).Connect("localhost", 3333)
Start-Sleep -Seconds 2

ssh -p 2201 admin@localhost
```

### Test 3: Service Access
```bash
# Web server should be accessible
curl http://192.168.10.2  # From any allowed network

# AAA RADIUS should only work from NAC network
# From NAC network device:
echo "User-Name=test" | radclient 192.168.1.10:1812 auth secret

# From other networks - should fail
```

### Test 4: Attack Simulation
```bash
# Simulate brute force (will trigger fail2ban)
for i in {1..5}; do ssh wronguser@192.168.1.10; done

# Check if blocked
sudo fail2ban-client status sshd

# Simulate DDoS (will trigger rate limiting)
for i in {1..200}; do curl http://192.168.10.2 & done

# Check dropped connections
sudo iptables -L -v -n | grep DROP
```

---

## UNDERSTANDING EACH PROTECTION

### Why Each Protection Matters in Your Topology:

| Protection | Why It's Critical | Where Applied | What It Prevents |
|------------|------------------|---------------|------------------|
| **Stateful Firewall** | Tracks connections | All devices | Unauthorized access |
| **Port Knocking** | Hides management | All devices | SSH scanning/brute force |
| **DDoS Protection** | Service availability | Web server, Routers | Service disruption |
| **ARP Protection** | Prevent MITM | All servers | Traffic interception |
| **Rate Limiting** | Resource protection | Web server | Resource exhaustion |
| **Fail2ban** | Automated defense | All servers | Brute force attacks |
| **Network Segmentation** | Containment | Routers | Lateral movement |
| **Logging** | Incident detection | All devices | Undetected breaches |

### Security Layers in Action:

1. **Attacker from Internet** → NAC Router firewall → Blocks unauthorized
2. **Attacker tries SSH scan** → Port knocking → Port not visible
3. **Attacker floods Web** → Rate limiting → Connections dropped
4. **Attacker spoofs ARP** → ARP protection → Spoofed packets dropped
5. **Attacker brute forces** → Fail2ban → IP banned

---


