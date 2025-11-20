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

**Why verify?** Ensure basic connectivity before applying security rules.

### Step 1.2: Install Required Software on Debian Nodes

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

sudo apt install fail2ban    
```

**Why these tools?**
- `iptables`: Main firewall
- `fail2ban`: Brute force protection
- `aide`: File integrity monitoring
- `arptables`: ARP attack protection

---

## PHASE 2: IMPLEMENT BASIC FIREWALL RULES

### Step 2.1: Configure AAA Server Firewall

AAA

```bash
#!/bin/bash
# AAA Server Firewall – Configuración de seguridad unificada con port-knocking

# ============= VARIABLES =============
AAA_IP="192.168.1.1"
NAC_IP="192.168.1.2"
WEB_IP="192.168.10.2"
BACKUP_IP="10.0.2.5"

# ============ LIMPIEZA =============
iptables -F                     # Borra todas las reglas actuales de las cadenas
iptables -X                     # Borra cadenas personalizadas
iptables -Z                     # Reinicia contadores

# ============ POLÍTICAS POR DEFECTO =============
iptables -P INPUT DROP          # Deniega todo el tráfico entrante por defecto
iptables -P FORWARD DROP        # No reenvía paquetes (no es router)
iptables -P OUTPUT DROP         # **Restricción saliente**: deniega todo tráfico saliente no autorizado

# ============ LOOPBACK =============
iptables -A INPUT -i lo -j ACCEPT      # Permite tráfico local desde loopback (localhost)
iptables -A OUTPUT -o lo -j ACCEPT     # Permite tráfico saliente hacia loopback

# ============ ANTI-SPOOFING =============
iptables -A INPUT -s 127.0.0.0/8 ! -i lo -j DROP        # Bloquea paquetes con IP loopback que no provengan de la interfaz local
iptables -A INPUT -s $AAA_IP ! -i lo -j DROP            # Bloquea spoofing: descarta paquetes con la IP del servidor AAA como origen desde otras interfaces

# ============ CONEXIONES ESTABLECIDAS =============
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT   # Permite tráfico entrante perteneciente a conexiones ya establecidas o relacionadas
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP                # **Seguridad**: descarta paquetes entrantes inválidos (corruptos o fuera de estado)

# ============ ICMP (PING) =============
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/s -j ACCEPT   # Permite ICMP echo-request (ping) entrante, limitado a 5 por segundo para mitigar abusos

# ============ ANTI-DDoS (SYN FLOOD) =============
iptables -N ANTI_DDOS                        # Crea cadena personalizada para control de SYN flood
iptables -A INPUT -j ANTI_DDOS               # Redirige tráfico TCP entrante a la cadena ANTI_DDOS
iptables -A ANTI_DDOS -p tcp --syn -m limit --limit 100/s --limit-burst 150 -j RETURN   # Permite hasta 100 conexiones SYN por segundo (burst 150)
iptables -A ANTI_DDOS -j DROP                # Descarta el exceso de paquetes SYN (protección contra SYN flood)

# ============ SSH DIRECTO DESDE NAC =============
iptables -A INPUT -s $NAC_IP -p tcp --dport 22 -j ACCEPT   # Permite acceso SSH directo desde el router NAC (origen confiable de administración)

# ============ PORT-KNOCKING (3 pasos para SSH) =============
iptables -A INPUT -p tcp --dport 7000 -m recent --name KNOCK1 --set -j DROP          # Knock 1: registra la IP origen al tocar puerto 7000, luego descarta
iptables -A INPUT -p tcp --dport 8000 -m recent --name KNOCK1 --rcheck --seconds 15 \
          -m recent --name KNOCK2 --set -j DROP                                     # Knock 2: válido solo si el knock 1 se realizó en los últimos 15s
iptables -A INPUT -p tcp --dport 9000 -m recent --name KNOCK2 --rcheck --seconds 15 \
          -m recent --name KNOCK3 --set -j DROP                                     # Knock 3: válido solo si el knock 2 se realizó en los últimos 15s
iptables -A INPUT -p tcp --dport 22 -m recent --name KNOCK3 --update --seconds 30 --reap -j ACCEPT  # Permite SSH si se completaron los 3 knocks en menos de 30s

# Limpieza de estado de knocks pasados (remueve la IP de las listas una vez concedido acceso)
iptables -A INPUT -m recent --name KNOCK1 --remove
iptables -A INPUT -m recent --name KNOCK2 --remove
iptables -A INPUT -m recent --name KNOCK3 --remove

#  OBSERVACIÓN PORT-KNOCKING:
# Una vez abierta la conexión SSH mediante port-knocking, la IP se elimina de las listas (--remove).
# Esto permite acceso continuo durante la sesión actual (mientras la conexión permanezca establecida via conntrack).
# Si la sesión se cierra e intenta abrirse otra sin repetir la secuencia de knocks, **será bloqueada**.
# Si no se comporta así, verificar estados conntrack o reglas que mantengan la sesión abierta inadvertidamente.

# ============ NTP (SERVICIO DE HORA) =============
iptables -A INPUT -p udp --dport 123 -s 192.168.1.0/24 -m limit --limit 10/s -j ACCEPT    # Permite consultas NTP entrantes desde la red NAC (máx. 10 por segundo)
iptables -A INPUT -p udp --dport 123 -s 192.168.10.0/24 -m limit --limit 10/s -j ACCEPT   # Permite consultas NTP entrantes desde la red DMZ (máx. 10 por segundo)

# ============ RADIUS (AAA) =============
iptables -A INPUT -p udp --dport 1812 -s 192.168.1.0/24 -j ACCEPT   # Permite solicitudes de autenticación RADIUS (puerto 1812) desde la red NAC
iptables -A INPUT -p udp --dport 1813 -s 192.168.1.0/24 -j ACCEPT   # Permite solicitudes de accounting RADIUS (puerto 1813) desde la red NAC
iptables -A INPUT -p udp --dport 1812 -s 10.1.1.0/24 -j ACCEPT      # Permite solicitudes RADIUS entrantes desde la red Supplicant (10.1.1.0/24)
iptables -A INPUT -p udp --dport 1813 -s 10.1.1.0/24 -j ACCEPT      # Permite solicitudes RADIUS (accounting) desde la red Supplicant

# ============ SYSLOG =============
iptables -A INPUT -p udp --dport 514 -s $WEB_IP -j ACCEPT   # Acepta tráfico Syslog entrante solo desde el servidor Web (DMZ) para registro centralizado

# ============ PROTECCIÓN CONTRA ESCANEOS =============
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP               # Descarta escaneo TCP tipo "NULL" (paquete sin flags)
iptables -A INPUT -p tcp --tcp-flags ALL FIN -j DROP                # Descarta escaneo TCP con solo FIN (FIN scan)
iptables -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP        # Descarta escaneo TCP tipo "XMAS" (flags FIN+PSH+URG activas, sin SYN/ACK)
iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST -j DROP            # Descarta paquetes TCP con combinación inválida SYN+RST (posible escaneo/ataque)
iptables -A INPUT -p tcp --tcp-flags ALL SYN,FIN -j DROP            # Descarta paquetes TCP con combinación inválida SYN+FIN (posible escaneo/ataque)
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP                # Descarta paquetes TCP con **todas** las flags activas (patrón anómalo)

# ============ OUTPUT (SALIENTE) =============
iptables -A OUTPUT -d $AAA_IP -p udp --dport 514 -j ACCEPT          # **Permite enviar logs** al servidor AAA (si AAA actúa como colector de syslog)
iptables -A OUTPUT -d $AAA_IP -p udp --dport 123 -j ACCEPT          # Permite sincronizar hora (NTP) con el servidor AAA
iptables -A OUTPUT -d $BACKUP_IP -p tcp --dport 873 -j ACCEPT       # Permite conexiones rsync salientes hacia el servidor Backup
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT                     # Permite consultas DNS salientes (UDP)
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT                     # Permite consultas DNS salientes (TCP, uso menos común)
iptables -A OUTPUT -p udp --dport 123 -j ACCEPT                    # Permite tráfico NTP saliente (sincronización con servidores de hora externos)
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT                    # Permite tráfico HTTPS saliente (actualizaciones, repositorios)
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT                     # Permite tráfico HTTP saliente (actualizaciones, repositorios)

# ============ LOGGING =============
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "AAA-DROP: "  # Registra intentos entrantes bloqueados (máx 5 por minuto para evitar inundar los logs)

# ============ DROP FINAL =============
iptables -A INPUT -j DROP   # Aplica política por defecto: deniega cualquier otro tráfico no permitido (seguridad por defecto)

# ============ GUARDADO =============
iptables-save > /etc/iptables/rules.v4   # Guarda las reglas en configuración persistente

```

Port Knocking

```bash

# ============ OTRA VERSION DE PORT KNOCKING ============
# ============ PORT-KNOCKING (Requiere knock cada vez) ============
# Primer knock (puerto 7000): marca IP como KNOCK1
iptables -A INPUT -p tcp --dport 7000 -m recent --name KNOCK1 --set -j DROP

# Segundo knock (puerto 8000): sólo si hizo el knock1 en los últimos 15s, marca como KNOCK2
iptables -A INPUT -p tcp --dport 8000 \
    -m recent --name KNOCK1 --rcheck --seconds 15 \
    -m recent --name KNOCK2 --set -j DROP

# Tercer knock (puerto 9000): sólo si hizo el knock2 en los últimos 15s, marca como KNOCK3
iptables -A INPUT -p tcp --dport 9000 \
    -m recent --name KNOCK2 --rcheck --seconds 15 \
    -m recent --name KNOCK3 --set -j DROP

# Permitir SSH sólo si completó knocking correctamente hace menos de 30s (rcheck)
iptables -A INPUT -p tcp --dport 22 \
    -m recent --name KNOCK3 --rcheck --seconds 30 \
    -j ACCEPT

# Eliminar marcas al final para requerir knocking en cada nueva conexión
iptables -A INPUT -m recent --name KNOCK1 --remove
iptables -A INPUT -m recent --name KNOCK2 --remove
iptables -A INPUT -m recent --name KNOCK3 --remove
```
---


BACKUP
```bash
#!/bin/bash
# Backup Server Firewall – Reglas de firewall para proteger el servidor de backups
# Con Port Knocking para acceso SSH adicional

# ============= VARIABLES =============
BACKUP_IP="10.0.2.5"
NAC_WAN_IP="10.0.2.4"   # IP del router NAC en la red externa (NAT)

# ============= LIMPIEZA =============
iptables -F
iptables -X
iptables -Z

# ============= POLÍTICAS POR DEFECTO =============
iptables -P INPUT DROP       # Deniega todo tráfico entrante no autorizado (política por defecto)
iptables -P FORWARD DROP     # No reenvía paquetes (servidor no actúa como router)
iptables -P OUTPUT DROP      # Restringe todo tráfico saliente por defecto (se permitirán solo servicios necesarios)

# ============= LOOPBACK =============
iptables -A INPUT -i lo -j ACCEPT        # Acepta tráfico local (loopback) entrante
iptables -A OUTPUT -o lo -j ACCEPT       # Acepta tráfico local saliente

# ============= ANTI-SPOOFING =============
iptables -A INPUT -s 127.0.0.0/8 ! -i lo -j DROP       # Bloquea paquetes spoofing con IP loopback desde interfaces no loopback
iptables -A INPUT -s $BACKUP_IP ! -i lo -j DROP        # Bloquea paquetes con la propia IP del Backup como origen en interfaces distintas a loopback

# ============= CONEXIONES ESTABLECIDAS =============
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT   # Acepta tráfico entrante de conexiones establecidas/relacionadas
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP                 # Descarta inmediatamente cualquier paquete inválido entrante

# ============= ICMP (PING) =============
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/s -j ACCEPT   # Permite ping entrante de diagnóstico (limitado a 5 por segundo)

# ============= ANTI-DDoS (SYN FLOOD) =============
iptables -N SYN_FLOOD
iptables -A INPUT -p tcp --syn -j SYN_FLOOD
iptables -A SYN_FLOOD -m limit --limit 100/s --limit-burst 150 -j RETURN  # Permite hasta 100 SYN/seg (burst 150)
iptables -A SYN_FLOOD -j DROP                                            # Descarta SYN excedentes (protección SYN flood)

# ============= ACCESOS ADMIN/RESPALDO (DESDE NAC) =============
iptables -A INPUT -s $NAC_WAN_IP -p tcp --dport 22 -j ACCEPT    # SSH directo solo desde el router NAC (red de gestión confiable)
iptables -A INPUT -s $NAC_WAN_IP -p tcp --dport 873 -j ACCEPT   # rsync (puerto 873) solo desde NAC (clientes internos via NAT)

# ============= PORT KNOCKING PARA SSH ADICIONAL =============
# Secuencia: TCP 7000 -> 8000 -> 9000 (en < 15s entre golpes) y luego abre SSH (22) durante 30s para esa IP

# Knock 1: primer golpe en 7000
iptables -A INPUT -p tcp --dport 7000 \
    -m recent --name KNOCK1 --set -j DROP

# Knock 2: segundo golpe en 8000 si KNOCK1 existe hace <15s
iptables -A INPUT -p tcp --dport 8000 \
    -m recent --name KNOCK1 --rcheck --seconds 15 \
    -m recent --name KNOCK2 --set -j DROP

# Knock 3: tercer golpe en 9000 si KNOCK2 existe hace <15s
iptables -A INPUT -p tcp --dport 9000 \
    -m recent --name KNOCK2 --rcheck --seconds 15 \
    -m recent --name KNOCK3 --set -j DROP

# Permitir SSH (22) si la secuencia KNOCK3 es válida en los últimos 30s
iptables -A INPUT -p tcp --dport 22 \
    -m recent --name KNOCK3 --update --seconds 30 --reap \
    -j ACCEPT

# Limpieza de marcas de port knocking para evitar estados viejos
iptables -A INPUT -m recent --name KNOCK1 --remove
iptables -A INPUT -m recent --name KNOCK2 --remove
iptables -A INPUT -m recent --name KNOCK3 --remove

# ============= SALIDA (TRÁFICO PERMITIDO) =============
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT        # DNS saliente (UDP)
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT        # DNS saliente (TCP)
iptables -A OUTPUT -p udp --dport 123 -j ACCEPT       # NTP saliente
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT        # HTTP saliente (actualizaciones del sistema)
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT       # HTTPS saliente (actualizaciones del sistema)

# ============= LOGGING =============
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "BACKUP-DROP: "  # Registra a baja frecuencia los intentos de acceso no autorizados

# ============= DROP FINAL =============
iptables -A INPUT -j DROP   # Descarta cualquier otro tráfico entrante no permitido (refuerzo, aunque la política ya es DROP)

# ============= GUARDADO =============
iptables-save > /etc/iptables/rules.v4

```

```bash
#!/bin/bash
# Web Server Firewall – Reglas de DMZ con protección DDoS y Port-Knocking

# ============= VARIABLES =============
WEB_IP="192.168.10.2"
AAA_IP="192.168.1.1"
BACKUP_IP="10.0.2.5"
DMZ_GW="192.168.10.1"     # IP del router NAC en la DMZ (gateway del Web)

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
iptables -A INPUT -s $DMZ_GW -p tcp --dport 22 -j ACCEPT   # Permite SSH desde el router NAC (gateway DMZ) para gestión

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
/ip firewall filter

# INPUT CHAIN  (tráfico dirigido al router NAC)
add chain=input action=accept connection-state=established,related comment="INPUT: Allow established/related"
add chain=input action=drop connection-state=invalid comment="INPUT: Drop invalid packets"
add chain=input action=accept in-interface=lo comment="INPUT: Allow loopback"
add chain=input action=accept protocol=icmp src-address=192.168.1.0/24 comment="INPUT: Allow ICMP from NAC network"
add chain=input action=accept protocol=icmp src-address=192.168.10.0/24 comment="INPUT: Allow ICMP from DMZ network"
add chain=input action=accept protocol=icmp src-address=10.1.1.0/24 comment="INPUT: Allow ICMP from Supplicant1 network"
add chain=input action=accept protocol=udp src-address=192.168.1.0/24 dst-port=67,68 comment="INPUT: Allow DHCP requests from NAC network"
add chain=input action=accept protocol=udp src-address=192.168.10.0/24 dst-port=67,68 comment="INPUT: Allow DHCP requests from DMZ network"
add chain=input action=drop protocol=udp in-interface=ether1 dst-port=67,68 comment="INPUT: Block DHCP from external (WAN) interface"
add chain=input action=accept protocol=tcp src-address-list=MGMT dst-port=22 comment="INPUT: SSH from MGMT (trusted management addresses)"
add chain=input action=accept protocol=tcp src-address-list=MGMT dst-port=8291 comment="INPUT: WinBox from MGMT (trusted)"
add chain=input action=add-src-to-address-list protocol=tcp address-list=knock_stage1 address-list-timeout=15s dst-port=1111 comment="INPUT: Port knock stage 1"
add chain=input action=add-src-to-address-list protocol=tcp src-address-list=knock_stage1 address-list=knock_stage2 address-list-timeout=15s dst-port=2222 comment="INPUT: Port knock stage 2"
add chain=input action=add-src-to-address-list protocol=tcp src-address-list=knock_stage2 address-list=knock_stage3 address-list-timeout=10m dst-port=3333 comment="INPUT: Port knock stage 3 (access granted)"
add chain=input action=accept protocol=tcp src-address-list=knock_stage3 dst-port=22 comment="INPUT: SSH after knocking"
add chain=input action=accept protocol=tcp src-address-list=knock_stage3 dst-port=8291 comment="INPUT: WinBox after knocking"
add chain=input action=log protocol=tcp src-address-list=!knock_stage3 dst-port=22 log-prefix="SSH-NO-KNOCK:" comment="INPUT: Log SSH attempt without knock"
add chain=input action=drop protocol=tcp src-address-list=!knock_stage3 dst-port=22 comment="INPUT: Drop SSH without knock"
add chain=input action=drop protocol=tcp src-address-list=!knock_stage3 dst-port=8291 comment="INPUT: Drop WinBox without knock"
add chain=input action=drop tcp-flags=fin,!syn,!rst,!psh,!ack,!urg protocol=tcp comment="INPUT: Drop FIN scan (stealth FIN)"
add chain=input action=drop tcp-flags=syn,rst protocol=tcp comment="INPUT: Drop SYN-RST scan"
add chain=input action=drop tcp-flags=fin,syn protocol=tcp comment="INPUT: Drop SYN-FIN scan"
add chain=input action=drop tcp-flags=!fin,!syn,!rst,!psh,!ack,!urg protocol=tcp comment="INPUT: Drop NULL scan (no flags)"
add chain=input action=drop tcp-flags=fin,psh,urg,!syn,!rst,!ack protocol=tcp comment="INPUT: Drop XMAS scan (FIN+PSH+URG)"
add chain=input action=log limit=1/10s packet-size=1-65535 log-prefix="INPUT-DROP:" comment="INPUT: Log dropped input"
add chain=input action=drop comment="INPUT: Drop all other input"

# FORWARD CHAIN (tráfico a través del router, entre interfaces)
add chain=forward action=accept connection-state=established,related comment="FORWARD: Allow established/related"
add chain=forward action=drop connection-state=invalid comment="FORWARD: Drop invalid"
add chain=forward action=drop protocol=tcp connection-limit=50,32 dst-address=192.168.10.2 dst-port=80 comment="FORWARD: Limit HTTP conn per IP to Web server"
add chain=forward action=drop protocol=tcp connection-limit=50,32 dst-address=192.168.10.2 dst-port=443 comment="FORWARD: Limit HTTPS conn per IP to Web server"
add chain=forward action=accept src-address=192.168.10.0/24 dst-address=!192.168.0.0/16 comment="FORWARD: Allow DMZ to Internet"
add chain=forward action=accept src-address=192.168.10.0/24 dst-address=192.168.1.0/24 comment="FORWARD: Allow DMZ to NAC network (e.g., Web to DB/AAA)"
add chain=forward action=accept src-address=192.168.1.0/24 dst-address=!192.168.0.0/16 comment="FORWARD: Allow NAC to Internet"
add chain=forward action=accept src-address=192.168.1.0/24 dst-address=192.168.10.0/24 comment="FORWARD: Allow NAC to DMZ network"
add chain=forward action=accept src-address=10.1.1.0/24 comment="FORWARD: Supplicant1 a cualquier destino"
add chain=forward action=accept src-address=10.1.2.0/24 comment="FORWARD: Supplicant gateway a cualquier destino"
add chain=forward action=drop protocol=tcp tcp-flags=syn connection-limit=100,32 comment="FORWARD: Drop SYN flood (>100 new SYN/s per IP)"
add chain=forward action=drop src-address=192.168.0.0/16 out-interface=ether1 comment="FORWARD: Drop private src 192.168.x.x heading to Internet"
add chain=forward action=drop src-address=172.16.0.0/12 out-interface=ether1 comment="FORWARD: Drop private src 172.16.x.x heading to Internet"
add chain=forward action=log limit=1/10s packet-size=1-65535 log-prefix="FWD-DROP:" comment="FORWARD: Log dropped forward"
add chain=forward action=drop comment="FORWARD: Drop all other forward"

# OUTPUT CHAIN (tráfico originado por el router NAC)
# (Nota: Por defecto, el router NAC permite sus propias conexiones salientes. Se podría restringir con reglas similares a hosts si fuera necesario, e.j. DNS, NTP)


## NAT NAC

```routeros
/ip firewall nat

# NAT: NAC network to Internet
add chain=srcnat action=masquerade src-address=192.168.1.0/24 out-interface=ether1 comment="NAT: NAC network to Internet"

# NAT: DMZ network to Internet
add chain=srcnat action=masquerade src-address=192.168.10.0/24 out-interface=ether1 comment="NAT: DMZ network to Internet"

# NAT: NAT network to Internet (VirtualBox)
add chain=srcnat action=masquerade src-address=10.0.2.0/24 out-interface=ether1 comment="NAT: NAT network to Internet (VirtualBox)"

# ✅ NUEVAS REGLAS PARA RED SUPPLICANT

# NAT: Supplicant1 network to Internet
add chain=srcnat action=masquerade src-address=10.1.1.0/24 out-interface=ether1 comment="NAT: Supplicant1 network to Internet"

# NAT: Supplicant gateway to Internet
add chain=srcnat action=masquerade src-address=10.1.2.0/24 out-interface=ether1 comment="NAT: Supplicant gateway to Internet"
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
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048

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





