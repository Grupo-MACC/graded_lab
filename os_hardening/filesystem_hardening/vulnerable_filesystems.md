
## 2. Preventing Vulnerable Filesystems

Prevent installation of file systems that can be attack vectors. We use the fake install method.

**Create configuration file:**
```bash
nano /etc/modprobe.d/securityclass.conf
```

**File contents:**
```bash
install cramfs echo "You won't install it, bye, bye..."
install freevxfs echo "It's not free"
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs echo "Go squat, spaghetti legs"
install udf /bin/true
install vfat /bin/true
```
