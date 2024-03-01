# A Definitive Automated Hardening Framework for Ubuntu 🔐

The following bash framework stands up and installs several bespoke security toolkits, developed to provide seamless automatic security controls for Ubuntu servers.

### Primary Toolkits
- [x] SSH Intrusion Detection (Custom Daemon) /w Email Alerts & Logs
- [x] Auditd (Hardened Configuration) - /w Email Alerts & Logs
- [x] Automated Fail2Ban Deployment (Hardened Restrictive Configuration with incremental bans) - /w Email Alerts, Logs & Whitelisting
- [x] Automated Upgrading Installation (Security & Critical) Deployment - Cron Jobs, Email Alerts & Logs
- [x] Automated RKHunter Deployment - Scans, Email Alerts, and Cron Job (Daily) (Weekly) /w Email Reports & Logs
- [x] Automated Lynis Deployment - Scans, Source Builds, Fingerprinting, Email Alerts, and Cron Job (Daily) (Weekly) /w Email Reports & Logs
- [x] Firewall (UFW) Deployment - Default Deny, pre-deployment testing, and Email Alerts & Logs
- [x] Automated Shared Memory Hardening & Restriction Deployment (/run/shm)
- [x] Automated Network Kernel Hardening Deployment (TCP/IP Stack Hardening) (E.g., DDoS Mitigation, ICMP, SYN Flood, etc.)
- [x] Automated AppArmor Deployment - Customized Enforcing Profiles & Logging
- [x] Automated Password Policy Deployment - Highly Conservative Configuration & Logging (e.g., Password Complexity, Length, etc.)
- [x] Automated SSH Hardening Deployment - Includes MFA, Key-Based Authentication & Hardened Configuration (e.g., AllowUsers, AllowGroups, etc.)

### Extra Toolkits
- [x] SSH Key generation, keyscan and deployment Scripts (optional)
- [x] Administrative user account creation and hardening (optional)
- [x] AWS DKIM & DMARC Configuration Deployment Toolkits (optional)
- [x] Automated Postfix Forwarding Service Deployment (optional)

### Installation

```bash
git clone https://github.com/error-try-again/auto-harden-ubuntu.git
cd auto-harden-ubuntu/hardening
```

### Configuration

Modify the default ip (5.5.5.5) in `/hardening/standalones/fail2ban/setup_fail2ban.sh` to ips which you would like to whitelist, replace the default email addresses (example.com) and modify the files in `/hardening/standalone/sshd/allowed_users.txt` & `/hardening/standalone/sshd/allowed_users_keys.txt` to include your own users and public keys of the users you want to allow to connect to the server.

### Execution

The script can be executed directly or as a series of individual standalone scripts.

Directly as a single script
```bash
pwd # /hardening
chmod +x automated_hardening.sh
./automated_hardening.sh
```

Or as a series of individual standalone scripts
```bash
cd /hardening/standalones
find . -type f -name '*.sh' -exec bash {} \;
```

Or individually
```bash
cd /hardening/standalones
chmod +x *.sh
./setup_auditd.sh
# etc...
```

# Roadmap
- [ ] Add precise configuration examples & documentation
- [ ] Additional toolkits (e.g., further kernel hardening, automatic audit remediation, etc.)
- [ ] Additional controls for alerts and logs
- [ ] Streamline configuration for easy deployment
- [ ] Email digests for alerts

# Notes
If for some reason you need to reinstall apt installed configuration files to their defaults, e.g. pam.d, you can use the following command:

```bash
sudo apt install --reinstall -o Dpkg::Options::="--force-confmiss" $(dpkg -S /etc/pam.d/\* | cut -d ':' -f 1)
```