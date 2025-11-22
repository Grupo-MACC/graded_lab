# Backup Configuration: Jump Host + Port Knocking

This document describes the complete configuration for performing secure backups from the Backup VM to the AAA server (and other internal servers), using:

- A router acting as SSH jump host
- Port knocking to temporarily open SSH
- A backup script executed from the Backup VM
- Cron jobs to schedule periodic backups

Everything is contained in this single document for direct deployment.

## 1. Architecture Overview

**Backup Path**  
Backup VM → Router (jump host) → AAA

**Security Layers:**
1. **Port Knocking**  
   - Router SSH port (22) is closed by default.  
   - AAA SSH port (22) is also closed by default.  
   - Both only open when the correct knock sequence is executed.

2. **Jump Host**  
   - The Backup VM never connects directly to AAA.  
   - All SSH traffic passes through the Router using `ssh -J`.

## 2. Backup Script: /scripts/backup_aaa.sh

**Permissions:**
chmod +x /scripts/backup_aaa.sh

### Script
<pre>```
#!/bin/bash
# AAA-specific variables
ROUTER_IP="10.0.2.4"          # Router / jump host
AAA_IP="192.168.10.1"         # AAA server IP
AAA_USER="backup"             # SSH user on AAA
AAA_PATH="/var/backups_aaa"   # Source directory on AAA
# Destination directory on Backup VM
DEST="/backups/aaa/${TYPE}_$(date +%F)"
mkdir -p "$DEST"

echo "[+] Starting ${TYPE} backup of AAA ..."
echo "[+] Step 1: Port knocking on Router"

# 1) Backup -> Router: port knocking
knock "$ROUTER_IP" 1111 2222 3333 -d 200

# 2) Backup -> Router: request knock to AAA
ssh admin@"$ROUTER_IP" "knock $AAA_IP 7000 8000 9000 -d 200"

# 3) Backup -> AAA through Router (jump host)
rsync -avz -e "ssh -J admin@${ROUTER_IP}" "${AAA_USER}@${AAA_IP}:${AAA_PATH}/" "$DEST/"
echo "[+] AAA backup completed"

echo "[+] AAA backup completed"
```</pre>

## 3. Cron Configuration
Cron is responsible for when the backup runs; the script decides what to do based on the argument:
- daily → daily incremental backup
- weekly → weekly full backup
- monthly → monthly full/off-site backup
The Backup VM uses root’s crontab to schedule /scripts/backup_aaa.sh.

**Edit root crontab:**
crontab -e

**Add Backup Schedules**
For example:
<pre>```
# AAA – daily backup at 02:00
0 2 * * * /scripts/backup_aaa.sh daily

# AAA – weekly backup (Sunday) at 02:00
0 2 * * 0 /scripts/backup_aaa.sh weekly

# AAA – monthly backup (day 1 of each month) at 02:00
0 2 1 * * /scripts/backup_aaa.sh monthly
```</pre>

## 4. Backup Execution Flow(End-to-End)

1. **Cron triggers on the Backup VM**
- Example: <pre>```0 2 * * * /scripts/backup_aaa.sh daily```</pre>
- The script starts with the argument daily.

2. **Backup VM runs the script**
- Script lives in /scripts/backup_aaa.sh.```</pre>
- It creates <pre>```/backups/aaa/daily_YYYY-MM-DD/ (or weekly_, monthly_).```</pre>

3. **Backup VM → Router: port knocking**
- Command (inside the script): <pre>```knock 10.0.2.4 1111 2222 3333 -d 200```</pre>
- The Router temporarily opens SSH (port 22) for the Backup VM.

4. **Backup VM → Router: ask Router to knock AAA**
- Command (inside the script): <pre>```ssh admin@10.0.2.4 "knock 192.168.10.1 7000 8000 9000 -d 200"```</pre>
- AAA opens SSH (port 22) only after the correct knock sequence.

5. **Backup VM → AAA via jump host**
- rsync runs with the router as jump host:
<pre>```rsync -avz -e "ssh -J admin@10.0.2.4" \
  backup@192.168.10.1:/var/backups_aaa/ \
  /backups/aaa/daily_2025-02-14/```</pre>
- Effective path: Backup VM → Router (SSH) → AAA (SSH)

6. **Files are written to the final destination**
- Example final path on Backup VM: <pre>```/backups/aaa/daily_2025-02-14/```</pre>
- This directory contains the copied AAA backup files for that day.

## 5. Reusing the Pattern for Other VMs

To back up additional VMs (e.g., Web server, databases):
1. Create a new script (e.g., /scripts/backup_web.sh) with:
- Its own IPs and source paths.
- The same knock → jump host → rsync pattern.

2. Add new cron entries with appropriate frequencies.

This keeps a consistent, auditable model:
- Scripts define how and what to back up.
- Cron defines when backups run.
