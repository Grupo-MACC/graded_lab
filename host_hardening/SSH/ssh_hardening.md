# SSH Hardening Setup Guide

This guide covers:

- Install sudo
- Add user with individual sudo privileges
- Create SSH key & deploy to server
- Set correct permissions
- Harden SSH config via include file
- Validate & restart SSH

---

## Install `sudo`

```bash
su -
apt update && apt install -y sudo
```

## Add user to sudo individually
Do not add to sudo group — add explicit rule in sudoers.
Open sudoers securely:
```bash
visudo
```
Add this line (replace user with your username):
```bash
user ALL=(root) PASSWD: ALL
```

## Create SSH Key
In PowerShell:
```bash
ssh-keygen -t ed25519 -C "InfrastructureAndNetworkSecurity"
```
The key will be generated at:
```bash
%USERPROFILE%\.ssh\id_ed25519
```

## Upload key to server
Copy public key:
```bash
%USERPROFILE%\.ssh\id_ed25519
```
Connect to server using password:
```bash
ssh user@localhost -p xxxx
```
Create authorized_keys:
```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh

nano ~/.ssh/authorized_keys
```
Paste the public key, save, then:
```bash
chmod 600 ~/.ssh/authorized_keys
```
Test login:
```bash
ssh user@localhost -p xxxx
```

## Copy Hardened SSH Config
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

## Validate SSH configuration
```bash
sudo sshd -t
```
If there's no output, config is good

## Restart SSH service
sudo systemctl restart ssh