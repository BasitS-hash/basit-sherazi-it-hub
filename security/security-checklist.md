# IT Security Hardening Checklist

> Use `scripts/security/security-hardening-check.sh --report` to automate many of these checks on Linux.

---

## System Hardening

### Linux / macOS

- [ ] All system packages updated to latest (`apt upgrade -y` / `brew upgrade`)
- [ ] Automatic security updates configured (unattended-upgrades / dnf-automatic)
- [ ] Unused services disabled and stopped (`systemctl list-units --state=failed`)
- [ ] Core dumps disabled (`ulimit -c 0` in /etc/security/limits.conf)
- [ ] `/tmp` mounted with `noexec,nosuid,nodev`
- [ ] World-writable files audited (`find / -xdev -perm -0002 -type f`)
- [ ] SUID/SGID binaries outside standard paths investigated

### Windows

- [ ] Windows Update set to automatic (Critical + Security)
- [ ] Windows Defender (or EDR) active and up to date
- [ ] BitLocker enabled on all drives
- [ ] PowerShell execution policy set appropriately (not `Unrestricted`)
- [ ] AppLocker or Windows Defender Application Control configured
- [ ] Local Administrator account renamed and disabled where possible

---

## User & Identity

- [ ] No accounts with empty passwords (`awk -F: '$2==""' /etc/shadow`)
- [ ] Root SSH login disabled (`PermitRootLogin no`)
- [ ] SSH password authentication disabled in favour of key-based auth
- [ ] MFA enforced for all privileged accounts and VPN access
- [ ] Principle of least privilege applied — users not in unnecessary sudo/admin groups
- [ ] Service accounts have non-interactive shells and no SSH key access
- [ ] Stale/unused accounts disabled or removed
- [ ] Password policy: min 12 chars, complexity, max 90-day rotation

---

## Network Security

- [ ] Firewall active and configured (ufw/iptables/Windows Firewall)
- [ ] Default deny inbound; explicit allow for needed services only
- [ ] SSH running on non-default port (or protected by port-knocking / VPN)
- [ ] Remote management (RDP, SSH) restricted to known IP ranges
- [ ] Default router/switch credentials changed
- [ ] Network segmentation in place (VLAN per trust zone)
- [ ] VPN required for remote access to internal services
- [ ] DNS-over-HTTPS or DNS-over-TLS configured
- [ ] Unused network interfaces disabled
- [ ] IPv6 forwarding disabled if not acting as a router

---

## Logging & Monitoring

- [ ] Centralised logging configured (rsyslog / journald forwarding)
- [ ] Auditd rules capturing privilege escalation and sensitive file access
- [ ] SSH login attempts logged and alerting on excessive failures (fail2ban)
- [ ] Log retention policy defined (min 90 days recommended)
- [ ] Integrity monitoring on critical files (AIDE / Tripwire)
- [ ] Uptime/availability monitoring in place

---

## Backup & Recovery

- [ ] Backup strategy documented (3-2-1: 3 copies, 2 media, 1 offsite)
- [ ] Automated backups running and verified (test restore monthly)
- [ ] Backup logs reviewed regularly
- [ ] Recovery time objective (RTO) and recovery point objective (RPO) defined
- [ ] Incident response plan documented and rehearsed

---

## Application & Data

- [ ] Web applications behind a WAF or reverse proxy
- [ ] TLS 1.2+ only; TLS 1.0/1.1 and SSLv3 disabled
- [ ] HTTPS enforced (HSTS headers set)
- [ ] No default credentials on any installed services
- [ ] Database not exposed directly to the internet
- [ ] Sensitive data encrypted at rest
- [ ] API keys and secrets stored in a secrets manager, not in source code

---

## Scored Summary

Run `scripts/security/security-hardening-check.sh --report` and attach the output.

| Category | Score (manual) |
|----------|---------------|
| System Hardening | /7 |
| User & Identity | /10 |
| Network Security | /10 |
| Logging & Monitoring | /6 |
| Backup & Recovery | /5 |
| Application & Data | /7 |
| **Total** | **/45** |
