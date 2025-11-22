# SSH Hardening Setup Guide

This guide covers:

- Creating and deploying SSH keys
- Configuring MikroTik NAC router as a secure jump host
- Hardening Debian VMs SSH configuration
- Validating and restarting SSH services safely
- Hardening MikroTik SSH configuration 

---

## 1. Create SSH Keys & Deploy to Servers
Generate three separate SSH key pairs on your local machine (%USERPROFILE% on Windows):
### 1.1 Backup VM (recommended: ed25519)
```bash
ssh-keygen -t ed25519 -C "InfrastructureAndNetworkSecurity"
```
### 1.2 NAC Router Access Key
```bash
ssh-keygen -t rsa -b 4096 -f router_id_rsa -C "NAC Router Access Key"
```
This key pair will be used to authenticate to the MikroTik router.
### 1.3 Internal Debian VM Key (MUST be PEM format)
```bash
ssh-keygen -t rsa -b 4096 -m PEM -f internal_debian_key -C "Internal Debian Key"
```
MikroTik only accepts RSA private keys in PEM format, hence -m PEM.
### 1.4 Deploy Public Keys to Each Server
Repeat this process for every Linux-based system (Debian VM and Backup VM):
```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys   # paste public key here
chmod 600 ~/.ssh/authorized_keys
```
Make sure the pasted key is on one line with no extra spaces.

## 2. Configure NAC Router as a Jump Host
To reach the internal Debian VM, the MikroTik acts as a jump server.
Two keys must be uploaded to the router:
| Key | Purpose |
|--------|---------|
| `router_id_rsa.pub` | Public key to authenticate into the router |
| `internal_debian_key` | Private key the router will use to authenticate into Debian VM |

Upload these two files to the MikroTik using SCP.
### 2.1 Import the Key Used to Log Into the Router
```bash
/user ssh-keys import public-key-file=router_id_rsa.pub
```
After importing, check:
```bash
/user ssh-keys print
```
### 2.2 Import the Key Used for Jumping to Debian VM
```bash
/user ssh-keys private import private-key-file=internal_debian_key
```
If MikroTik shows “wrong format or bad passphrase”, the key is not PEM or contains a passphrase.
Verify that MikroTik accepted it:
```bash
/user ssh-keys private print
```
### 2.3 Test the Jump Connection
From the MikroTik terminal:
```bash
/system ssh address=192.168.10.2 user=user
```
If configured correctly:
- SSH will not ask for a password
- Login should be automatic using the imported key

## 3. Harden SSH Configuration (Debian / Linux Servers)
Edit main config:
```bash
sudo nano /etc/ssh/sshd_config
```
Ensure it contains:
```bash
Include /etc/ssh/sshd_config.d/*.conf
```
Copy the content of hardened_sshd_config_example file

## Important `sshd_config` Settings Explained
| Setting | Purpose | Recommended |
|--------|---------|------------|
| `PermitRootLogin` | Allow or block direct SSH root login | `no` (use sudo instead) |
| `PasswordAuthentication` | Allow password login | `no` if using SSH keys |
| `PubkeyAuthentication` | Enable SSH key authentication | `yes` |
| `PermitEmptyPasswords` | Allow accounts with no password | `no` |
| `KbdInteractiveAuthentication` | Keyboard-interactive login methods | `no` |
| `UsePAM` | Enable PAM for system login policies | `yes` |
| `AllowTcpForwarding` | Allow SSH tunneling/port forwarding | `no` unless needed |
| `GatewayPorts` | Allow remote forwarded ports to bind publicly | `no` |
| `X11Forwarding` | Allow GUI/X11 forwarding | `no` |
| `PermitUserEnvironment` | Allow user-defined environment variables (security risk) | `no` |
| `MaxAuthTries` | Maximum failed authentication attempts | `3–4` |
| `LogLevel` | SSH logging level | `VERBOSE` for auditing |
| `ClientAliveInterval` | Timeout before disconnecting idle clients | `120` (example) |
| `ClientAliveCountMax` | Number of keepalive retries before disconnect | `2–3` |
| `Include` | Load extra config files (modular config) | `Include /etc/ssh/sshd_config.d/*.conf` |

## 4. Validate SSH configuration
Always validate before restarting, to avoid locking yourself out:
```bash
sudo sshd -t
```
If there are no errors:
```bash
sudo systemctl restart ssh
```

## 5. Hardening MikroTik SSH configuration
MikroTik RouterOS provides several options to secure and harden SSH access.
The following settings reduce the attack surface, enforce strong crypto, and ensure that only authorized key-based logins are allowed.
### 5.1 Enforce Strong Cryptography
```bash
ip ssh set strong-crypto=yes
```
This disables:
- SSHv1
- Weak/legacy algorithms
### 5.2 Disable Password Authentication (key-only login)
Make sure key-based login is confirmed working before disabling passwords.
```bash
ip ssh set always-allow-password-login=no
```
