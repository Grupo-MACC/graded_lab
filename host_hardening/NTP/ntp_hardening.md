# NTP Hardening Setup Guide

This guide covers:

- NTP installation
- NTP configuration

The AAA/NTP server synchronizes with external servers (Google / pool.ntp.org).

All internal machines synchronize their time against the internal NTP server.

---

## Install `chrony`

```bash
su -
apt install chrony -y
```

