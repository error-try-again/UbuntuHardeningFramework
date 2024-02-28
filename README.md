# A Definitive Automated Hardening Framework for Ubuntu 🔐

The following bash framework stands up and installs the following bespoke security toolkits via the 
`automated_hardening.sh` script. The script is designed to be run on a fresh Ubuntu installation.

### Primary Toolkits
- [x] SSH Intrusion Detection (Custom Daemon) /w Email Alerts & Logs
- [x] Auditd (Hardened Configuration) - /w Email Alerts & Logs
- [x] Automated Fail2Ban Deployment (Restrictive Configuration with incremental bans) - /w Email Alerts & Logs
- [x] Automated Upgrading Installation (Security & Critical) Deployment - Bespoke Cron Jobs, Email Alerts & Logs
- [x] Automated RKHunter Deployment - Scans, Email Alerts, and Cron Job (Daily) (Weekly)
- [x] Automated Lynis Deployment - Scans, Source Builds, Fingerprinting, Email Alerts, and Cron Job (Daily) (Weekly) 
- [x] Firewall (UFW) Deployment - Default Deny, pre-deployment testing, and Email Alerts & Logs
- [x] Automated Shared Memory Hardening & Restriction Deployment
- [x] Automated Network Kernel Hardening Deployment (TCP/IP Stack Hardening) (E.g., DDoS Mitigation, ICMP, SYN Flood, etc.)
- [x] Automated AppArmor Deployment - Bespoke Profiles & Logs
- [x] Automated Password Policy Deployment - Bespoke Configuration & Logs
- [x] Automated SSH Hardening Deployment - Includes MFA, Key-Based Authentication, and highly defensive configuration

### Extras Toolkits
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

Finally, run the script with the following commands to start the hardening process.
```bash
chmod +x automated_hardening.sh
./automated_hardening.sh
```
