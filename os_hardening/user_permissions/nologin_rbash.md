## 1. User and Shell Configuration

### Shell Restriction
All users should have `nologin` as their shell, except for the main user with SSH access.

**Verification:**
```bash
cat /etc/passwd
```

**Change shell to nologin if needed:**
```bash
usermod -s /usr/sbin/nologin username
```

**Configure restricted bash for the main user:**
```bash
usermod -s /bin/rbash user
```
This forces the user to escalate privileges to perform administrative operations.

### Installing and configuring sudo
```bash
apt update && apt install -y sudo
cat /etc/sudoers
```
Ensure that only root is configured, except in exceptional cases.