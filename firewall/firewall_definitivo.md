# Infrastructure and Network Security - Graded Lab

## SECURITY STRATEGY OVERVIEW

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
| **Web Server** | Public-facing service | Receives external requests |
| **Backup Server** | Data storage | Contains sensitive backups |
| **NAC Router** | Main gateway | Controls all traffic flow |
| **NAC2 and Supplicant1 Router** | Redirect traffic | Exposed |


## PHASE 1: IMPLEMENT BASIC FIREWALL RULES

AAA

```bash
#!/bin/bash
# AAA Server Firewall – with working Ping + working Port-Knocking + Anti-DDoS without conflicts

# ============= VARIABLES =============
AAA_IP="192.168.1.1"
NAC_IP="192.168.1.2"
WEB_IP="192.168.10.2"
BACKUP_IP="10.0.2.5"

# ============ CLEANUP =============
iptables -F
iptables -X
iptables -Z

# ============ DEFAULT POLICIES =============
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP     # Restricted output (but we allow ICMP reply and DNS/NTP/etc.)

# ============ LOOPBACK =============
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# ============ ESTABLISHED CONNECTIONS =============
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ============ ICMP (PING) – MUST GO BEFORE ANTI-DDoS =============
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/s -j ACCEPT
iptables -A OUTPUT -p icmp -j ACCEPT        # Allows ping responses (VERY IMPORTANT)

# ============ PORT-KNOCKING (3 steps for SSH) =============

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

# === SSH after knock: RULE 1 (only check) ===
iptables -A INPUT -p tcp --dport 22 \
    -m recent --name KNOCK3 --rcheck --seconds 30 \
    -j ACCEPT

# === SSH after knock: RULE 2 (update state) ===
iptables -A INPUT -p tcp --dport 22 \
    -m recent --name KNOCK3 --update --seconds 30 --reap \
    -j ACCEPT

# Cleanup
iptables -A INPUT -m recent --name KNOCK1 --remove
iptables -A INPUT -m recent --name KNOCK2 --remove
iptables -A INPUT -m recent --name KNOCK3 --remove

# ============ DIRECT SSH FROM NAC (no knocking) =============
#iptables -A INPUT -s $NAC_IP -p tcp --dport 22 -j ACCEPT

# ============ ANTI-DDoS (SYN FLOOD) – AFTER ICMP and PK ============
iptables -N ANTI_DDOS
iptables -A INPUT -p tcp -m tcp --syn -j ANTI_DDOS
iptables -A ANTI_DDOS -m limit --limit 100/s --limit-burst 150 -j RETURN
iptables -A ANTI_DDOS -j DROP

# ============ NTP (TIME SERVICE) =============
iptables -A INPUT -p udp --dport 123 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p udp --dport 123 -s 192.168.10.0/24 -j ACCEPT
iptables -A INPUT -p udp --dport 123 -s 10.1.1.0/24 -j ACCEPT
iptables -A INPUT -p udp --dport 123 -s 10.1.2.0/24 -j ACCEPT

# ============ RADIUS (AAA) =============
iptables -A INPUT -p udp --dport 1812 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p udp --dport 1813 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p udp --dport 1812 -s 10.1.1.0/24 -j ACCEPT
iptables -A INPUT -p udp --dport 1813 -s 10.1.1.0/24 -j ACCEPT

# ============ SYSLOG =============
iptables -A INPUT -p udp --dport 514 -s $WEB_IP -j ACCEPT

# ============ SCAN PROTECTION =============
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL FIN -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL SYN,FIN -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# ============ AUTHORIZED OUTPUT =============
iptables -A OUTPUT -d $AAA_IP -p udp --dport 514 -j ACCEPT
iptables -A OUTPUT -d $AAA_IP -p udp --dport 123 -j ACCEPT
iptables -A OUTPUT -d $BACKUP_IP -p tcp --dport 873 -j ACCEPT

iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

iptables -A OUTPUT -p udp --dport 123 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT

# ============ LOGGING =============
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "AAA-DROP: "

# ============ FINAL DROP =============
iptables -A INPUT -j DROP

# ============ ARP PROTECTION (RECOMMENDED) =============
sysctl -w net.ipv4.conf.all.arp_ignore=1
sysctl -w net.ipv4.conf.all.arp_announce=2

arptables -F
arptables -A INPUT -d $AAA_IP -j ACCEPT
arptables -A INPUT -s $NAC_IP -j ACCEPT
arptables -A INPUT -j DROP
arptables-save > /etc/arptables/rules.v4

# ============ SAVE RULES =============
iptables-save > /etc/iptables/rules.v4


```


---


BACKUP SERVER

```bash
#!/bin/bash
# Backup Server Hardened Firewall (Direct Port-Knocking + DNS Fix)

# ==================================================
# Flush existing rules
# ==================================================
iptables -F               # Delete all rules
iptables -X               # Delete all custom chains
iptables -Z               # Reset packet counters

# ==================================================
# Default Policies
# ==================================================
iptables -P INPUT DROP    # Block all incoming traffic by default
iptables -P FORWARD DROP  # Do not forward traffic (server is not a router)
iptables -P OUTPUT ACCEPT # Allow all outgoing traffic

# ==================================================
# Loopback Interface
# ==================================================
iptables -A INPUT -i lo -j ACCEPT   # Allow local loopback traffic
iptables -A OUTPUT -o lo -j ACCEPT

# ==================================================
# Allow Established / Related Connections
# ==================================================
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ==================================================
# DNS Response Fix (allow replies from port 53)
# ==================================================
iptables -A INPUT -p udp --sport 53 -j ACCEPT   # Allow DNS responses (UDP)
iptables -A INPUT -p tcp --sport 53 -j ACCEPT   # Allow DNS responses (TCP)

# ==================================================
# ICMP (only from NAT internal network)
# ==================================================
iptables -A INPUT -p icmp -s 10.0.2.0/24 -j ACCEPT   # Allow ICMP from internal NAT

# ==================================================
# PORT KNOCKING (direct mode, 7000 → 8000 → 9000)
# ==================================================

# Knock 1: port 7000
iptables -A INPUT -p tcp --dport 7000 \
    -m recent --name KNOCK1 --set -j DROP     # Register knock 1 and drop packet

# Knock 2: port 8000 (must occur within 15s after knock 1)
iptables -A INPUT -p tcp --dport 8000 \
    -m recent --name KNOCK1 --rcheck --seconds 15 \
    -m recent --name KNOCK2 --set -j DROP     # Register knock 2 and drop packet

# Knock 3: port 9000 (must occur within 15s after knock 2)
iptables -A INPUT -p tcp --dport 9000 \
    -m recent --name KNOCK2 --rcheck --seconds 15 \
    -m recent --name KNOCK3 --set -j DROP     # Register knock 3 and drop packet

# Allow SSH if the 3-knock sequence was completed (within 30 seconds)
iptables -A INPUT -p tcp --dport 22 \
    -m recent --name KNOCK3 --update --seconds 30 --reap \
    -j ACCEPT                                  # Allow SSH after valid knock sequence

# Cleanup: remove old knock states to force fresh sequences
iptables -A INPUT -m recent --name KNOCK1 --remove
iptables -A INPUT -m recent --name KNOCK2 --remove
iptables -A INPUT -m recent --name KNOCK3 --remove

# ==================================================
# RSYNC (tcp/873) only from AAA + Web Server
# ==================================================
iptables -A INPUT -p tcp --dport 873 -s 192.168.1.1 -j ACCEPT   # Allow rsync from AAA server
iptables -A INPUT -p tcp --dport 873 -s 192.168.10.2 -j ACCEPT  # Allow rsync from Web server

# Limit simultaneous rsync connections (max 10)
iptables -A INPUT -p tcp --dport 873 -m connlimit --connlimit-above 10 -j REJECT

# ==================================================
# OUTPUT Rules (DNS, NTP, Updates)
# ==================================================
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT   # Allow outgoing DNS (UDP)
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT   # Allow outgoing DNS (TCP)

iptables -A OUTPUT -p udp --dport 123 -j ACCEPT  # Allow outgoing NTP

iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT   # Allow outgoing HTTP
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT  # Allow outgoing HTTPS

# ==================================================
# Logging
# ==================================================
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "BKP-DROP: "   # Log dropped packets (rate limited)

# ==================================================
# Save rules to persistent storage
# ==================================================
iptables-save > /etc/iptables/rules.v4


```
WEB SERVER

```bash
#!/bin/bash
# Web Server Firewall – DMZ rules with DDoS protection and Port-Knocking

# ============= VARIABLES =============
WEB_IP="192.168.10.2"
AAA_IP="192.168.1.1"
BACKUP_IP="10.0.2.5"
DMZ_GW="192.168.10.1"     # IP of the NAC router in the DMZ (Web server gateway)
WEB_DB_IP="192.168.1.3"

# ============= CLEANUP =============
iptables -F           # Delete existing rules
iptables -X           # Delete custom chains
iptables -Z           # Reset counters

# ============= POLICIES =============
iptables -P INPUT DROP       # Deny all incoming traffic by default
iptables -P FORWARD DROP     # Do not forward traffic (server is not a router)
iptables -P OUTPUT ACCEPT    # Allow all outgoing traffic by default

# ============= LOOPBACK =============
iptables -A INPUT -i lo -j ACCEPT         # Allow local (loopback) traffic
iptables -A OUTPUT -o lo -j ACCEPT

# ============= ESTABLISHED CONNECTIONS =============
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT   # Allow traffic from established/related connections

# ============= DIRECT SSH FROM DMZ GW =============
#iptables -A INPUT -s $DMZ_GW -p tcp --dport 22 -j ACCEPT   # Allow SSH from the NAC router (DMZ gateway) for management

# ============= PORT-KNOCKING (on-demand SSH access) =============
iptables -A INPUT -p tcp --dport 7000 -m recent --name KNOCK1 --set -j DROP          # First knock
iptables -A INPUT -p tcp --dport 8000 -m recent --name KNOCK1 --rcheck --seconds 15 \
          -m recent --name KNOCK2 --set -j DROP                                      # Second knock (within 15s of the first)
iptables -A INPUT -p tcp --dport 9000 -m recent --name KNOCK2 --rcheck --seconds 15 \
          -m recent --name KNOCK3 --set -j DROP                                      # Third knock (within 15s of the second)
iptables -A INPUT -p tcp --dport 22 -m recent --name KNOCK3 --rcheck --seconds 30 -j ACCEPT   # Allow SSH if knock sequence completed in <30s

# Remove knock marks so that a new knock sequence is required next time
iptables -A INPUT -m recent --name KNOCK1 --remove
iptables -A INPUT -m recent --name KNOCK2 --remove
iptables -A INPUT -m recent --name KNOCK3 --remove

# ============= LIMITED ICMP =============
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/s -j ACCEPT   # Allow incoming ping (limited to 5 per second)

# ============= SYN FLOOD PROTECTION =============
iptables -N SYN_FLOOD
iptables -A INPUT -p tcp --syn -j SYN_FLOOD
iptables -A SYN_FLOOD -m limit --limit 100/s --limit-burst 150 -j RETURN   # Allow up to 100 SYN/s (burst 150)
iptables -A SYN_FLOOD -j DROP                                             # Block excessive SYNs

# ============= HTTP/HTTPS WITH LIMITS =============
iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 100 -j REJECT --reject-with tcp-reset    # Limit to 100 concurrent HTTP connections per IP
iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 100 -j REJECT --reject-with tcp-reset   # Limit to 100 concurrent HTTPS connections per IP

iptables -A INPUT -p tcp --dport 80 -m recent --name HTTP --update --seconds 1 --hitcount 20 -j DROP   # Limit new HTTP connections to 20 per second per IP
iptables -A INPUT -p tcp --dport 80 -m recent --name HTTP --set
iptables -A INPUT -p tcp --dport 443 -m recent --name HTTPS --update --seconds 1 --hitcount 20 -j DROP  # Limit new HTTPS connections to 20 per second per IP
iptables -A INPUT -p tcp --dport 443 -m recent --name HTTPS --set

iptables -A INPUT -p tcp --dport 80 -j ACCEPT    # Allow HTTP (80) after passing previous filters
iptables -A INPUT -p tcp --dport 443 -j ACCEPT   # Allow HTTPS (443) after passing previous filters

# ============== WEB =================
iptables -A INPUT -s $WEB_DB_IP -p tcp --dport 3306 -j ACCEPT   # Allow MariaDB traffic from DB server

# ============= OUTPUT =============
iptables -A OUTPUT -d $AAA_IP -p udp --dport 514 -j ACCEPT    # Send logs to AAA server (centralized syslog)
iptables -A OUTPUT -d $AAA_IP -p udp --dport 123 -j ACCEPT    # Query NTP from AAA server (internal time)
iptables -A OUTPUT -d $BACKUP_IP -p tcp --dport 873 -j ACCEPT # Send backups (rsync) to Backup server

iptables -A OUTPUT -p udp --dport 53 -j ACCEPT    # Outgoing DNS (UDP)
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT    # Outgoing DNS (TCP)
## iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT   # (Optional) Outgoing HTTP for updates
## iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT  # (Optional) Outgoing HTTPS for updates

# ============= LOGGING =============
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "WEB-DROP: "   # Basic logging for dropped incoming packets

# ============= FINAL DROP =============
iptables -A INPUT -j DROP    # Drop any remaining incoming traffic

# ============= SAVE =============
iptables-save > /etc/iptables/rules.v4

# ARP SPOOFING PROTECTION
sysctl -w net.ipv4.conf.all.arp_ignore=1       # Kernel: do not respond to ARP that is not directed to this host
sysctl -w net.ipv4.conf.all.arp_announce=2     # Kernel: announce only own IP in ARP (avoids conflicts)
arptables -F
arptables -A INPUT -d $WEB_IP -j ACCEPT        # Allow ARP destined to the Web server IP
arptables -A INPUT -s $DMZ_GW -j ACCEPT        # Allow ARP from the DMZ gateway (NAC router)
arptables -A INPUT -j DROP                     # Block any other ARP
arptables-save > /etc/arptables/rules.v4


```


## FILTER NAC

```routeros


# INPUT chain rules (traffic to the NAC router)
add chain=input action=accept connection-state=established,related comment="INPUT: Allow established/related connections"
add chain=input action=drop connection-state=invalid comment="INPUT: Drop invalid packets"
add chain=input action=accept in-interface=lo comment="INPUT: Allow loopback"
add chain=input action=accept protocol=icmp src-address=192.168.1.0/24 comment="INPUT: Allow ICMP from NAC network"
add chain=input action=accept protocol=icmp src-address=192.168.10.0/24 comment="INPUT: Allow ICMP from DMZ network"
add chain=input action=accept protocol=icmp src-address=10.1.1.0/24 comment="INPUT: Allow ICMP from Supplicant1 network"
add chain=input action=accept protocol=udp src-address=192.168.1.0/24 dst-port=67,68 comment="INPUT: Allow DHCP requests from NAC network"
add chain=input action=accept protocol=udp src-address=192.168.10.0/24 dst-port=67,68 comment="INPUT: Allow DHCP requests from DMZ network"
add chain=input action=drop protocol=udp in-interface=ether1 dst-port=67,68 comment="INPUT: Block DHCP from external (WAN) interface"
add chain=input action=accept protocol=tcp src-address-list=MGMT dst-port=22 comment="INPUT: Allow SSH from MGMT (trusted addresses)"
add chain=input action=accept protocol=tcp src-address-list=MGMT dst-port=8291 comment="INPUT: Allow WinBox from MGMT (trusted)"

# Port knocking
add chain=input action=add-src-to-address-list protocol=tcp address-list=knock_stage1 address-list-timeout=15s dst-port=1111 comment="INPUT: Port knock stage 1"
add chain=input action=add-src-to-address-list protocol=tcp src-address-list=knock_stage1 address-list=knock_stage2 address-list-timeout=15s dst-port=2222 comment="INPUT: Port knock stage 2"
add chain=input action=add-src-to-address-list protocol=tcp src-address-list=knock_stage2 address-list=knock_stage3 address-list-timeout=10m dst-port=3333 comment="INPUT: Port knock stage 3 (granted access)"
add chain=input action=accept protocol=tcp src-address-list=knock_stage3 dst-port=22 comment="INPUT: Allow SSH after knocking"
add chain=input action=accept protocol=tcp src-address-list=knock_stage3 dst-port=8291 comment="INPUT: Allow WinBox after knocking"
add chain=input action=log protocol=tcp src-address-list=!knock_stage3 dst-port=22 log-prefix="SSH-NO-KNOCK:" comment="INPUT: Log SSH attempts without knock"
add chain=input action=drop protocol=tcp src-address-list=!knock_stage3 dst-port=22 comment="INPUT: Drop SSH without knock"
add chain=input action=drop protocol=tcp src-address-list=!knock_stage3 dst-port=8291 comment="INPUT: Drop WinBox without knock"

# Scan detection
add chain=input action=drop tcp-flags=fin,!syn,!rst,!psh,!ack,!urg protocol=tcp comment="INPUT: Drop FIN stealth scan"
add chain=input action=accept protocol=udp dst-port=1812,1813,1645,1646 comment="INPUT: Allow RADIUS"
add chain=input action=drop tcp-flags=syn,rst protocol=tcp comment="INPUT: Drop SYN-RST scan"
add chain=input action=drop tcp-flags=fin,syn protocol=tcp comment="INPUT: Drop SYN-FIN scan"
add chain=input action=drop tcp-flags=!fin,!syn,!rst,!psh,!ack,!urg protocol=tcp comment="INPUT: Drop NULL scan"
add chain=input action=drop tcp-flags=fin,psh,urg,!syn,!rst,!ack protocol=tcp comment="INPUT: Drop XMAS scan"

add chain=input action=accept protocol=udp src-address=10.100.0.0/30 dst-address=192.168.1.1 comment="INPUT: Allow specific UDP traffic"

# FORWARD chain rules
add chain=forward action=drop connection-state=invalid comment="FORWARD: Drop invalid packets"
add chain=forward action=drop connection-limit=50,32 protocol=tcp dst-address=192.168.10.2 dst-port=80 comment="FORWARD: Limit HTTP connections per IP to Web server"
add chain=forward action=drop connection-limit=50,32 protocol=tcp dst-address=192.168.10.2 dst-port=443 comment="FORWARD: Limit HTTPS connections per IP to Web server"
add chain=forward action=accept src-address=192.168.10.0/24 dst-address=!192.168.0.0/16 comment="FORWARD: Allow DMZ to Internet"
add chain=forward action=accept src-address=192.168.10.0/24 dst-address=192.168.1.0/24 comment="FORWARD: Allow DMZ to NAC (e.g., Web to DB/AAA)"
add chain=forward action=accept src-address=192.168.1.0/24 dst-address=!192.168.0.0/16 comment="FORWARD: Allow NAC to Internet"
add chain=forward action=accept src-address=192.168.1.0/24 dst-address=192.168.10.0/24 comment="FORWARD: Allow NAC to DMZ"
add chain=forward action=accept src-address=10.1.1.0/24 comment="FORWARD: Allow Supplicant1 to any destination"
add chain=forward action=accept src-address=10.1.2.0/24 comment="FORWARD: Allow Supplicant gateway to any destination"
add chain=forward action=drop tcp-flags=syn connection-limit=100,32 protocol=tcp comment="FORWARD: Drop SYN flood (>100 new SYN/s per IP)"

# Prevent private IPs leaking to WAN
add chain=forward action=drop src-address=192.168.0.0/16 out-interface=ether1 comment="FORWARD: Drop private 192.168.x.x to WAN"
add chain=forward action=drop src-address=172.16.0.0/12 out-interface=ether1 comment="FORWARD: Drop private 172.16.x.x to WAN"


[admin@NAC] > ip firewall nat print
Flags: X - disabled, I - invalid; D - dynamic
 0    chain=srcnat action=masquerade out-interface=ether1

 1    ;;; NAT: NAC network to Internet
      chain=srcnat action=masquerade src-address=192.168.1.0/24 out-interface=ether1

 2    ;;; NAT: DMZ network to Internet
      chain=srcnat action=masquerade src-address=192.168.10.0/24 out-interface=ether1

 3    ;;; NAT: NAT network to Internet (VirtualBox)
      chain=srcnat action=masquerade src-address=10.0.2.0/24 out-interface=ether1

 4    ;;; NAT: Supplicant1 network to Internet
      chain=srcnat action=masquerade src-address=10.1.1.0/24 out-interface=ether1

 5    ;;; NAT: Supplicant gateway to Internet
      chain=srcnat action=masquerade src-address=10.1.2.0/24 out-interface=ether1


```

## NAT NAC

```routeros
add chain=srcnat action=masquerade out-interface=ether1 comment="NAT: Default masquerade"

add chain=srcnat action=masquerade src-address=192.168.1.0/24 out-interface=ether1 comment="NAT: NAC network to Internet"

add chain=srcnat action=masquerade src-address=192.168.10.0/24 out-interface=ether1 comment="NAT: DMZ network to Internet"

add chain=srcnat action=masquerade src-address=10.0.2.0/24 out-interface=ether1 comment="NAT: VirtualBox NAT network to Internet"

add chain=srcnat action=masquerade src-address=10.1.1.0/24 out-interface=ether1 comment="NAT: Supplicant1 network to Internet"

add chain=srcnat action=masquerade src-address=10.1.2.0/24 out-interface=ether1 comment="NAT: Supplicant gateway to Internet"

```


## FILTER Supplicant

```bash

/ip firewall filter
# INPUT chain rules (traffic to the Supplicant router itself)
add chain=input action=accept connection-state=established,related comment="INPUT: Allow established/related connections"
add chain=input action=drop connection-state=invalid comment="INPUT: Drop invalid packets"
add chain=input action=accept protocol=tcp src-address=192.168.1.0/24 dst-port=22 comment="INPUT: Allow SSH from NAC network (administration)"
add chain=input action=accept protocol=tcp src-address=192.168.1.0/24 dst-port=8291 comment="INPUT: Allow WinBox from NAC network (administration)"
add chain=input action=add-src-to-address-list protocol=tcp psd=21,3s,3,1 address-list=port_scanners address-list-timeout=1d comment="INPUT: Detect port scan (PSD)"
add chain=input action=add-src-to-address-list protocol=tcp tcp-flags=fin,!syn,!rst,!psh,!ack,!urg src-address-list=!port_scanners address-list=port_scanners address-list-timeout=1d comment="INPUT: Detect FIN stealth scan"
add chain=input action=add-src-to-address-list protocol=tcp tcp-flags=fin,psh,urg,!syn,!rst,!ack src-address-list=!port_scanners address-list=port_scanners address-list-timeout=1d comment="INPUT: Detect XMAS scan (FIN+PSH+URG)"
add chain=input action=add-src-to-address-list protocol=tcp tcp-flags=!fin,!syn,!rst,!psh,!ack,!urg src-address-list=!port_scanners address-list=port_scanners address-list-timeout=1d comment="INPUT: Detect NULL scan (no flags)"
add chain=input action=drop src-address-list=port_scanners comment="INPUT: Block source detected as port scanner"
add chain=input action=accept protocol=icmp limit=5/1s,10 comment="INPUT: Allow ICMP (ping) with rate limit"
add chain=input action=accept protocol=udp src-address=10.1.1.0/24 dst-port=67,68 comment="INPUT: Allow DHCP requests from Supplicant network (clients obtaining IP)"
add chain=input action=log log-prefix="INPUT DROP: " limit=1/5s comment="INPUT: Log and drop remaining traffic"
add chain=input action=drop comment="INPUT: Drop all other incoming traffic"

# FORWARD chain rules (traffic passing through the Supplicant router)
add chain=forward action=accept connection-state=established,related comment="FORWARD: Allow established/related traffic"
add chain=forward action=drop connection-state=invalid comment="FORWARD: Drop invalid packets"
add chain=forward action=drop protocol=tcp src-address=10.1.2.0/24 dst-address=192.168.10.2 dst-port=80 connection-limit=50,32 comment="FORWARD: Limit concurrent HTTP connections per IP (>50) to Web DMZ server"
add chain=forward action=drop protocol=tcp src-address=10.1.2.0/24 dst-address=192.168.10.2 dst-port=443 connection-limit=50,32 comment="FORWARD: Limit concurrent HTTPS connections per IP (>50) to Web DMZ server"
add chain=forward action=accept protocol=tcp src-address=10.1.2.0/24 dst-address=192.168.10.2 dst-port=80 comment="FORWARD: Allow HTTP from Supplicant Gateway to Web DMZ server"
add chain=forward action=accept protocol=tcp src-address=10.1.2.0/24 dst-address=192.168.10.2 dst-port=443 comment="FORWARD: Allow HTTPS from Supplicant Gateway to Web DMZ server"
add chain=forward action=accept src-address=10.1.1.0/24 comment="FORWARD: Allow Supplicant1 to any destination"
add chain=forward action=drop protocol=tcp tcp-flags=syn connection-limit=100,32 comment="FORWARD: Drop SYN flood (more than 100 new connections per IP)"
add chain=forward action=log log-prefix="FWD DROP: " limit=1/10s comment="FORWARD: Log dropped traffic"
add chain=forward action=drop comment="FORWARD: Drop all other forwarded traffic"


```


# NAT rules (enmascaramiento de la red Supplicant hacia DMZ)

```bash
/ip firewall nat add chain=srcnat action=masquerade src-address=10.1.2.0/24 out-interface=<VPN_INTERFACE> comment="NAT: Masquerade de Supplicant 10.1.2.0/24 hacia DMZ":contentReference[oaicite:1]{index=1}
```

## WEB_DB

```bash
#!/usr/sbin/nft -f
# Web/DB server firewall (DMZ + Internal networks)
flush ruleset

table inet webdb_filter {

    ##############################
    #   DYNAMIC PORT-KNOCK SETS  #
    ##############################
    set knock1 {
        type ipv4_addr;
        flags dynamic,timeout;
        timeout 15s;
    }

    set knock2 {
        type ipv4_addr;
        flags dynamic,timeout;
        timeout 15s;
    }

    set knock3 {
        type ipv4_addr;
        flags dynamic,timeout;
        timeout 30s;
    }

    ##############################
    #       PORT-KNOCK CHAIN     #
    ##############################
    chain KNOCK {
        # Knock 1: contacting TCP 7000 adds source IP to @knock1 and drops the packet
        tcp dport 7000 add @knock1 { ip saddr } drop

        # Knock 2: only valid if IP is in @knock1; contacting TCP 8000 adds IP to @knock2
        ip saddr @knock1 tcp dport 8000 add @knock2 { ip saddr } drop

        # Knock 3: only valid if IP is in @knock2; contacting TCP 9000 adds IP to @knock3
        ip saddr @knock2 tcp dport 9000 add @knock3 { ip saddr } drop

        # SSH allowed only if IP successfully passed the 3 knocking stages
        ip saddr @knock3 tcp dport 22 accept

        # Default: deny all direct SSH attempts
        tcp dport 22 drop
    }

    ##############################
    #           INPUT            #
    ##############################
    chain input {
        type filter hook input priority 0; policy drop;

        # Allow loopback and established connections
        iif "lo" accept
        ct state established,related accept

        # Drop invalid packets
        ct state invalid drop

        # Basic SYN flood protection (limit new TCP SYN to 100/s per source)
        ip protocol tcp tcp flags syn limit rate 100/second accept

        # Port-knocking processing
        jump KNOCK

        # Allow MySQL/MariaDB only from the Web server in the DMZ
        ip saddr 192.168.10.2 tcp dport 3306 accept

        # Allow ICMP echo requests (ping) with a reasonable rate limit
        ip protocol icmp limit rate 5/second accept

        # Log and drop anything else
        limit rate 5/minute log prefix "WEB_DB-DROP: " counter drop
    }

    ##############################
    #           OUTPUT           #
    ##############################
    chain output {
        type filter hook output priority 0; policy drop;

        # Allow loopback and established outbound traffic
        oif "lo" accept
        ct state established,related accept

        # Allow outbound DNS (UDP and TCP)
        udp dport 53 ct state new,related accept
        tcp dport 53 ct state new,related accept

        # Allow outbound NTP time sync
        udp dport 123 ct state new,related accept

        # Allow outbound rsync backups
        tcp dport 873 ct state new,related accept

        # Allow HTTP/HTTPS for updates or repositories
        tcp dport 80 ct state new,related accept
        tcp dport 443 ct state new,related accept

        # Everything else is blocked by default policy
    }
}


```

## PHASE 2: ADVANCED PROTECTIONS

### Protection Against ARP Spoofing

On each Debian server:
```bash


# Configure static ARP entries for critical hosts
# On AAA Server:
sudo arp -s 192.168.1.1 <NAC_ROUTER_MAC>  # Gateway

# Enable kernel protection
sudo bash -c 'cat >> /etc/sysctl.conf << EOF
# ARP spoofing protection
net.ipv4.conf.all.arp_filter = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
EOF'

sudo sysctl -p

# Configure arptables
sudo arptables -A INPUT --source-mac ! <GATEWAY_MAC> --source-ip 192.168.1.1 -j DROP
sudo arptables-save > /etc/arptables.rules
```

### DDoS extra Protection

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

# ARP Spoofing Protection + Fail2ban 

## 🔒 ARP Spoofing Protection (arptables + sysctl + static ARP)

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
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048

EOF'

sudo sysctl -p
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

---

# 🛡️ FAIL2BAN — Brute Force Protection


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

## PHASE 3: 802.1X Configuration on MikroTik routers

```routeros
 ip pool add name=Supplicant ranges=10.1.1.2-10.1.1.254
 ip dhcp-server network add address=10.1.1.0/24 dns-server=10.1.1.1 gateway=10.1.1.1
 ip dhcp-server add disabled=no address-pool=Supplicant authoritative=yes interface=ether4 name=Supplicant
 radius add disabled=no address=192.168.1.1 secret=shared_secret service=dot1x
 interface dot1x server add disabled=no accounting=yes auth-types=dot1x interface=ether4


```

## PHASE 4: MikroTik routers hardening:

### 1. Change default users

```routeros
/user
set admin password=pass
add name=secadmin password=Newpass group=full
remove admin
```

### 2. DISABLE UNNECESSARY SERVICES

```routeros
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
```

### 3. DISABLE UNUSED INTERFACES

```routeros
/interface
set ether5 disabled=yes
set ether6 disabled=yes
set ether7 disabled=yes
set ether8 disabled=yes
```

### 4. DISABLE WIRELESS WPS not for the hotspot

```routeros
/interface wireless
set wlan1 wps-mode=disabled
set wlan2 wps-mode=disabled
```








