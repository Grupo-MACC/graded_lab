# Infrastructure and Network Security - Graded Lab

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
| **Web Server** | Public-facing service | Receives external requests |
| **Backup Server** | Data storage | Contains sensitive backups |
| **NAC Router** | Main gateway | Controls all traffic flow |
| **NAC2 and Supplicant1 Router** | DMZ gateway | Bridges internal and DMZ |


## PHASE 1: IMPLEMENT BASIC FIREWALL RULES

### Step 2.1: Configure AAA Server Firewall

AAA

```bash
#!/bin/bash
# AAA Server Firewall – con Ping funcional + Port-Knocking funcional + Anti-DDoS sin conflictos

# ============= VARIABLES =============
AAA_IP="192.168.1.1"
NAC_IP="192.168.1.2"
WEB_IP="192.168.10.2"
BACKUP_IP="10.0.2.5"

# ============ LIMPIEZA =============
iptables -F
iptables -X
iptables -Z

# ============ POLÍTICAS POR DEFECTO =============
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP     # Salida restringida (pero permitimos ICMP reply y DNS/NTP/etc.)

# ============ LOOPBACK =============
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# ============ CONEXIONES ESTABLECIDAS =============
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ============ ICMP (PING) – TIENE QUE IR ANTES DEL ANTI-DDoS =============
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/s -j ACCEPT
iptables -A OUTPUT -p icmp -j ACCEPT        # Permite responder al ping (IMPORTANTÍSIMO)

# ============ PORT-KNOCKING (3 pasos para SSH) =============

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

# === SSH tras knock: REGRA 1 (solo comprobar) ===
iptables -A INPUT -p tcp --dport 22 \
    -m recent --name KNOCK3 --rcheck --seconds 30 \
    -j ACCEPT

# === SSH tras knock: REGLA 2 (actualizar estado) ===
iptables -A INPUT -p tcp --dport 22 \
    -m recent --name KNOCK3 --update --seconds 30 --reap \
    -j ACCEPT

# Limpieza
iptables -A INPUT -m recent --name KNOCK1 --remove
iptables -A INPUT -m recent --name KNOCK2 --remove
iptables -A INPUT -m recent --name KNOCK3 --remove

# ============ SSH DIRECTO DESDE NAC (sin knocking) =============
#iptables -A INPUT -s $NAC_IP -p tcp --dport 22 -j ACCEPT

# ============ ANTI-DDoS (SYN FLOOD) – DESPUÉS del ICMP y PK ============
iptables -N ANTI_DDOS
iptables -A INPUT -p tcp -m tcp --syn -j ANTI_DDOS
iptables -A ANTI_DDOS -m limit --limit 100/s --limit-burst 150 -j RETURN
iptables -A ANTI_DDOS -j DROP

# ============ NTP (SERVICIO DE HORA) =============
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

# ============ PROTECCIÓN CONTRA ESCANEOS =============
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL FIN -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL SYN,FIN -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# ============ OUTPUT AUTORIZADO =============
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

# ============ DROP FINAL =============
iptables -A INPUT -j DROP

# ============ PROTECCIÓN ARP (RECOMENDADA) =============
sysctl -w net.ipv4.conf.all.arp_ignore=1
sysctl -w net.ipv4.conf.all.arp_announce=2

arptables -F
arptables -A INPUT -d $AAA_IP -j ACCEPT
arptables -A INPUT -s $NAC_IP -j ACCEPT
arptables -A INPUT -j DROP
arptables-save > /etc/arptables/rules.v4

# ============ GUARDADO =============
iptables-save > /etc/iptables/rules.v4

```


---


BACKUP SERVER

```bash
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

```
WEB SERVER

```bash
#!/bin/bash
# Web Server Firewall – Reglas de DMZ con protección DDoS y Port-Knocking

# ============= VARIABLES =============
WEB_IP="192.168.10.2"
AAA_IP="192.168.1.1"
BACKUP_IP="10.0.2.5"
DMZ_GW="192.168.10.1"     # IP del router NAC en la DMZ (gateway del Web)
WEB_DB_IP="192.168.1.3"

# ============= LIMPIEZA =============
iptables -F           # Borra reglas existentes
iptables -X           # Borra cadenas personalizadas
iptables -Z           # Reinicia contadores

# ============= POLÍTICAS =============
iptables -P INPUT DROP       # Denegar todo tráfico entrante por defecto
iptables -P FORWARD DROP     # No reenviar (servidor no actúa como router)
iptables -P OUTPUT ACCEPT    # Permitir tráfico saliente por defecto

# ============= LOOPBACK =============
iptables -A INPUT -i lo -j ACCEPT         # Permite tráfico local (loopback)
iptables -A OUTPUT -o lo -j ACCEPT

# ============= CONEXIONES ESTABLECIDAS =============
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT   # Permite tráfico de conexiones ya establecidas/relacionadas

# ============= SSH DIRECTO DESDE DMZ GW =============
#iptables -A INPUT -s $DMZ_GW -p tcp --dport 22 -j ACCEPT   # Permite SSH desde el router NAC (gateway DMZ) para gestión

# ============= PORT-KNOCKING (acceso SSH bajo demanda) =============
iptables -A INPUT -p tcp --dport 7000 -m recent --name KNOCK1 --set -j DROP          # Primer knock
iptables -A INPUT -p tcp --dport 8000 -m recent --name KNOCK1 --rcheck --seconds 15 \
          -m recent --name KNOCK2 --set -j DROP                                      # Segundo knock (dentro de 15s del primero)
iptables -A INPUT -p tcp --dport 9000 -m recent --name KNOCK2 --rcheck --seconds 15 \
          -m recent --name KNOCK3 --set -j DROP                                      # Tercer knock (dentro de 15s del segundo)
iptables -A INPUT -p tcp --dport 22 -m recent --name KNOCK3 --rcheck --seconds 30 -j ACCEPT   # Permite SSH si la secuencia de knock se completó en <30s

# Eliminar marcas de knock para requerir la secuencia en cada conexión nueva
iptables -A INPUT -m recent --name KNOCK1 --remove
iptables -A INPUT -m recent --name KNOCK2 --remove
iptables -A INPUT -m recent --name KNOCK3 --remove

# ============= ICMP LIMITADO =============
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/s -j ACCEPT   # Permite ping entrante (limitado a 5 por segundo)

# ============= PROTECCIÓN SYN FLOOD =============
iptables -N SYN_FLOOD
iptables -A INPUT -p tcp --syn -j SYN_FLOOD
iptables -A SYN_FLOOD -m limit --limit 100/s --limit-burst 150 -j RETURN   # Permite hasta 100 SYN/s (burst 150)
iptables -A SYN_FLOOD -j DROP                                             # Bloquea exceso de SYNs

# ============= HTTP/HTTPS con LÍMITES =============
iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 100 -j REJECT --reject-with tcp-reset    # Limita a 100 conexiones concurrentes por IP para HTTP
iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 100 -j REJECT --reject-with tcp-reset   # Limita a 100 conexiones concurrentes por IP para HTTPS

iptables -A INPUT -p tcp --dport 80 -m recent --name HTTP --update --seconds 1 --hitcount 20 -j DROP   # Limita nuevas conexiones HTTP a 20 por segundo por IP
iptables -A INPUT -p tcp --dport 80 -m recent --name HTTP --set
iptables -A INPUT -p tcp --dport 443 -m recent --name HTTPS --update --seconds 1 --hitcount 20 -j DROP  # Limita nuevas conexiones HTTPS a 20 por segundo por IP
iptables -A INPUT -p tcp --dport 443 -m recent --name HTTPS --set

iptables -A INPUT -p tcp --dport 80 -j ACCEPT    # Permitir tráfico HTTP (80) tras pasar los filtros anteriores
iptables -A INPUT -p tcp --dport 443 -j ACCEPT   # Permitir tráfico HTTPS (443) tras pasar los filtros

# ============== WEB =================
iptables -A INPUT -s $WEB_DB_IP -p tcp --dport 3306 -j ACCEPT

# ============= SALIDA =============
iptables -A OUTPUT -d $AAA_IP -p udp --dport 514 -j ACCEPT    # Enviar logs al servidor AAA (syslog centralizado)
iptables -A OUTPUT -d $AAA_IP -p udp --dport 123 -j ACCEPT    # Consultar NTP al servidor AAA (hora interna)
iptables -A OUTPUT -d $BACKUP_IP -p tcp --dport 873 -j ACCEPT # Enviar backups (rsync) al servidor Backup

iptables -A OUTPUT -p udp --dport 53 -j ACCEPT    # DNS saliente (UDP)
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT    # DNS saliente (TCP)
## iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT   # (Opcional) HTTP saliente para actualizaciones
## iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT  # (Opcional) HTTPS saliente para actualizaciones


# ============= LOGGING =============
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "WEB-DROP: "   # Log básico de paquetes entrantes descartados

# ============= DROP FINAL =============
iptables -A INPUT -j DROP    # Descarta cualquier otro tráfico entrante

# ============= GUARDADO =============
iptables-save > /etc/iptables/rules.v4

# ARP SPOOFING PROTECTION
sysctl -w net.ipv4.conf.all.arp_ignore=1       # Kernel: no responder ARP que no vaya dirigido a este host
sysctl -w net.ipv4.conf.all.arp_announce=2     # Kernel: anunciar solo la IP propia en ARP (evita conflictos)
arptables -F
arptables -A INPUT -d $WEB_IP -j ACCEPT        # Permite ARP dirigido a la IP del Web server
arptables -A INPUT -s $DMZ_GW -j ACCEPT        # Permite ARP proveniente del gateway DMZ (router NAC)
arptables -A INPUT -j DROP                     # Bloquea cualquier otro ARP
arptables-save > /etc/arptables/rules.v4

```


## FILTER NAC

```routeros
[admin@NAC] > ip firewall filter print
Flags: X - disabled, I - invalid; D - dynamic
 0    ;;; INPUT: Allow established/related
      chain=input action=accept connection-state=established,related

 1    ;;; INPUT: Drop invalid packets
      chain=input action=drop connection-state=invalid

 2    ;;; INPUT: Allow loopback
      chain=input action=accept in-interface=lo

 3    ;;; INPUT: Allow ICMP from NAC network
      chain=input action=accept protocol=icmp src-address=192.168.1.0/24

 4    ;;; INPUT: Allow ICMP from DMZ network
      chain=input action=accept protocol=icmp src-address=192.168.10.0/24

 5    ;;; INPUT: Allow ICMP from Supplicant1 network
      chain=input action=accept protocol=icmp src-address=10.1.1.0/24

 6    ;;; INPUT: Allow DHCP requests from NAC network
      chain=input action=accept protocol=udp src-address=192.168.1.0/24 dst-port=67,68

 7    ;;; INPUT: Allow DHCP requests from DMZ network
      chain=input action=accept protocol=udp src-address=192.168.10.0/24 dst-port=67,68

 8    ;;; INPUT: Block DHCP from external (WAN) interface
      chain=input action=drop protocol=udp in-interface=ether1 dst-port=67,68

 9    ;;; INPUT: SSH from MGMT (trusted management addresses)
      chain=input action=accept protocol=tcp src-address-list=MGMT dst-port=22

10    ;;; INPUT: WinBox from MGMT (trusted)
      chain=input action=accept protocol=tcp src-address-list=MGMT dst-port=8291

11    ;;; INPUT: Port knock stage 1
      chain=input action=add-src-to-address-list protocol=tcp address-list=knock_stage1 address-list-timeout=15s
      dst-port=1111

12    ;;; INPUT: Port knock stage 2
      chain=input action=add-src-to-address-list protocol=tcp src-address-list=knock_stage1 address-list=knock_stage2
      address-list-timeout=15s dst-port=2222

13    ;;; INPUT: Port knock stage 3 (access granted)
      chain=input action=add-src-to-address-list protocol=tcp src-address-list=knock_stage2 address-list=knock_stage3
      address-list-timeout=10m dst-port=3333

14    ;;; INPUT: SSH after knocking
      chain=input action=accept protocol=tcp src-address-list=knock_stage3 dst-port=22

15    ;;; INPUT: WinBox after knocking
      chain=input action=accept protocol=tcp src-address-list=knock_stage3 dst-port=8291

16    ;;; INPUT: Log SSH attempt without knock
      chain=input action=log protocol=tcp src-address-list=!knock_stage3 dst-port=22 log-prefix="SSH-NO-KNOCK:"

17    ;;; INPUT: Drop SSH without knock
      chain=input action=drop protocol=tcp src-address-list=!knock_stage3 dst-port=22

18    ;;; INPUT: Drop WinBox without knock
      chain=input action=drop protocol=tcp src-address-list=!knock_stage3 dst-port=8291

19    ;;; INPUT: Drop FIN scan (stealth FIN)
      chain=input action=drop tcp-flags=fin,!syn,!rst,!psh,!ack,!urg protocol=tcp

20    ;;; Allow radius
      chain=input action=accept protocol=udp dst-port=1812,1813,1645,1646

21    ;;; INPUT: Drop SYN-RST scan
      chain=input action=drop tcp-flags=syn,rst protocol=tcp

22    ;;; INPUT: Drop SYN-FIN scan
      chain=input action=drop tcp-flags=fin,syn protocol=tcp

23    ;;; INPUT: Drop NULL scan (no flags)
      chain=input action=drop tcp-flags=!fin,!syn,!rst,!psh,!ack,!urg protocol=tcp

24    ;;; INPUT: Drop XMAS scan (FIN+PSH+URG)
      chain=input action=drop tcp-flags=fin,psh,urg,!syn,!rst,!ack protocol=tcp

25    chain=input action=accept protocol=udp src-address=10.100.0.0/30 dst-address=192.168.1.1

26    ;;; FORWARD: Drop invalid
      chain=forward action=drop connection-state=invalid

27    ;;; FORWARD: Limit HTTP conn per IP to Web server
      chain=forward action=drop connection-limit=50,32 protocol=tcp dst-address=192.168.10.2 dst-port=80

28    ;;; FORWARD: Limit HTTPS conn per IP to Web server
      chain=forward action=drop connection-limit=50,32 protocol=tcp dst-address=192.168.10.2 dst-port=443

29    ;;; FORWARD: Allow DMZ to Internet
      chain=forward action=accept src-address=192.168.10.0/24 dst-address=!192.168.0.0/16

30    ;;; FORWARD: Allow DMZ to NAC network (e.g., Web to DB/AAA)
      chain=forward action=accept src-address=192.168.10.0/24 dst-address=192.168.1.0/24

31    ;;; FORWARD: Allow NAC to Internet
      chain=forward action=accept src-address=192.168.1.0/24 dst-address=!192.168.0.0/16

32    ;;; FORWARD: Allow NAC to DMZ network
      chain=forward action=accept src-address=192.168.1.0/24 dst-address=192.168.10.0/24

33    ;;; FORWARD: Supplicant1 a cualquier destino
      chain=forward action=accept src-address=10.1.1.0/24

34    ;;; FORWARD: Supplicant gateway a cualquier destino
      chain=forward action=accept src-address=10.1.2.0/24

35    ;;; FORWARD: Drop SYN flood (>100 new SYN/s per IP)
      chain=forward action=drop tcp-flags=syn connection-limit=100,32 protocol=tcp

36    ;;; FORWARD: Drop private src 192.168.x.x heading to Internet
      chain=forward action=drop src-address=192.168.0.0/16 out-interface=ether1

37    ;;; FORWARD: Drop private src 172.16.x.x heading to Internet
      chain=forward action=drop src-address=172.16.0.0/12 out-interface=ether1

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

## FILTER Supplicant

```bash

/ip firewall filter

# INPUT chain rules (tráfico al propio router Supplicant)
add chain=input action=accept connection-state=established,related comment="INPUT: Permitir conexiones establecidas/relacionadas"
add chain=input action=drop connection-state=invalid comment="INPUT: Descartar paquetes inválidos"
add chain=input action=accept protocol=tcp src-address=192.168.1.0/24 dst-port=22 comment="INPUT: Permitir SSH desde red NAC (administración)"
add chain=input action=accept protocol=tcp src-address=192.168.1.0/24 dst-port=8291 comment="INPUT: Permitir WinBox desde red NAC (administración)"
add chain=input action=add-src-to-address-list protocol=tcp psd=21,3s,3,1 address-list=port_scanners address-list-timeout=1d comment="INPUT: Detectar scan de puertos (PSD)"
add chain=input action=add-src-to-address-list protocol=tcp tcp-flags=fin,!syn,!rst,!psh,!ack,!urg src-address-list=!port_scanners address-list=port_scanners address-list-timeout=1d comment="INPUT: Detectar scan tipo FIN (stealth)"
add chain=input action=add-src-to-address-list protocol=tcp tcp-flags=fin,psh,urg,!syn,!rst,!ack src-address-list=!port_scanners address-list=port_scanners address-list-timeout=1d comment="INPUT: Detectar scan tipo XMAS (FIN+PSH+URG)"
add chain=input action=add-src-to-address-list protocol=tcp tcp-flags=!fin,!syn,!rst,!psh,!ack,!urg src-address-list=!port_scanners address-list=port_scanners address-list-timeout=1d comment="INPUT: Detectar scan tipo NULL (sin flags)"
add chain=input action=drop src-address-list=port_scanners comment="INPUT: Bloquear origen listado como escáner"
add chain=input action=accept protocol=icmp limit=5/1s,10 comment="INPUT: Permitir ICMP (ping) limitado"
add chain=input action=accept protocol=udp src-address=10.1.1.0/24 dst-port=67,68 comment="INPUT: Permitir solicitudes DHCP desde red Supplicant (clientes obteniendo IP)"
add chain=input action=log log-prefix="INPUT DROP: " limit=1/5s comment="INPUT: Registrar y descartar restante"
add chain=input action=drop comment="INPUT: Descartar todo otro tráfico de entrada"

# FORWARD chain rules (tráfico a través del router Supplicant)
add chain=forward action=accept connection-state=established,related comment="FORWARD: Permitir tráfico establecido/relacionado"
add chain=forward action=drop connection-state=invalid comment="FORWARD: Descartar paquetes inválidos"
add chain=forward action=drop protocol=tcp src-address=10.1.2.0/24 dst-address=192.168.10.2 dst-port=80 connection-limit=50,32 comment="FORWARD: Limitar HTTP concurrente por IP (>50) hacia Web DMZ"
add chain=forward action=drop protocol=tcp src-address=10.1.2.0/24 dst-address=192.168.10.2 dst-port=443 connection-limit=50,32 comment="FORWARD: Limitar HTTPS concurrente por IP (>50) hacia Web DMZ"
add chain=forward action=accept protocol=tcp src-address=10.1.2.0/24 dst-address=192.168.10.2 dst-port=80 comment="FORWARD: Permitir HTTP desde Supplicant Gateway hacia servidor Web DMZ"
add chain=forward action=accept protocol=tcp src-address=10.1.2.0/24 dst-address=192.168.10.2 dst-port=443 comment="FORWARD: Permitir HTTPS desde Supplicant Gateway hacia servidor Web DMZ"
add chain=forward action=accept src-address=10.1.1.0/24 comment="FORWARD: Supplicant1 a cualquier destino"
add chain=forward action=drop protocol=tcp tcp-flags=syn connection-limit=100,32 comment="FORWARD: Descartar SYN flood (más de 100 conexiones nuevas/IP)"
add chain=forward action=log log-prefix="FWD DROP: " limit=1/10s comment="FORWARD: Log de tráfico bloqueado"
add chain=forward action=drop comment="FORWARD: Descartar todo otro tráfico forward"

```


# NAT rules (enmascaramiento de la red Supplicant hacia DMZ)

```bash
/ip firewall nat add chain=srcnat action=masquerade src-address=10.1.2.0/24 out-interface=<VPN_INTERFACE> comment="NAT: Masquerade de Supplicant 10.1.2.0/24 hacia DMZ":contentReference[oaicite:1]{index=1}
```

## WEB_DB

#!/usr/sbin/nft -f

# Limpiar reglas existentes
flush ruleset

# Definir tabla y cadenas de filtrado

```bash
#!/usr/sbin/nft -f
# Tabla y cadenas de filtrado para servidor Web/BD (DMZ e Interno)
flush ruleset

table inet webdb_filter {
    chain input {
        type filter hook input priority 0; policy drop;
        # Aceptar tráfico local y conexiones existentes
        iif "lo" accept
        ct state established,related accept
        ct state invalid drop       # Descartar paquetes inválidos que no correspondan a ninguna conexión
        
        # Protección contra SYN flood (limita a 100 conexiones SYN/segundo por origen)
        ip protocol tcp tcp flags syn limit rate 100/second accept

        # Port-knocking para SSH (secuencia requerida: 7000 -> 8000 -> 9000)
        set knock1 { type ipv4_addr; timeout 15s; }
        set knock2 { type ipv4_addr; timeout 15s; }
        set knock3 { type ipv4_addr; timeout 30s; }

        tcp dport 7000 add @knock1 drop        # Knock 1: registra IP origen al contactar puerto 7000
        ip saddr @knock1 tcp dport 8000 add @knock2 drop   # Knock 2: válido solo tras Knock1
        ip saddr @knock2 tcp dport 9000 add @knock3 drop   # Knock 3: válido solo tras Knock2
        ip saddr @knock3 tcp dport 22 accept    # Permite SSH desde IP origen si completó la secuencia de knocks correcta

        # Permitir acceso a base de datos **solo** desde el servidor Web en DMZ
        ip saddr 192.168.10.2 tcp dport 3306 accept    # Solo la IP del servidor Web puede acceder a MySQL/MariaDB

        # Permitir ICMP (ping) entrante con límite razonable
        ip protocol icmp limit rate 5/second accept

        # Registrar y **soltar** todo lo demás no permitido
        limit rate 5/minute log prefix "WEB_DB-DROP: "
        drop
    }

    chain output {
        type filter hook output priority 0; policy drop;
        # Permitir loopback y tráfico saliente ya establecido/relacionado
        oif "lo" accept
        ct state established,related accept

        # Permitir tráfico saliente necesario (DNS, NTP, Backup, actualizaciones)
        udp dport 53 accept      # Consultas DNS (UDP)
        tcp dport 53 accept      # Consultas DNS (TCP)
        udp dport 123 accept     # NTP hacia servidor de tiempo (sincronización de reloj)
        tcp dport 873 accept     # rsync hacia servidor Backup (transferencia de respaldos)
        tcp dport 80 accept      # (Opcional) HTTP saliente para actualizaciones/repositorios
        tcp dport 443 accept     # (Opcional) HTTPS saliente para actualizaciones/repositorios

        # El resto de tráfico saliente no está permitido (DROP por política por defecto)
    }
}
```

## PHASE 2: ADVANCED PROTECTIONS

### Step 2.1: Protection Against ARP Spoofing

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










