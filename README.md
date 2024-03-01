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

Generate a fresh ssh key on your local machine. 

```bash
0 % ssh-keygen -t ed25519 -C "void@null"
Generating public/private ed25519 key pair.
Enter file in which to save the key (/home/void/.ssh/id_ed25519): /home/void/.ssh/void-ed25519
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/void/.ssh/void-ed25519
Your public key has been saved in /home/void/.ssh/void-ed25519.pub
The key fingerprint is:
SHA256:0pOxo... void@null
void@null ~/.ssh
1 % cat void-ed25519.pub # Copy this key
```

The script can be executed directly or as a series of individual standalone scripts. If you're executing it as a single script, you can modify the `config.sh` file to include your SSH key mappings, allowed SSH users, Fail2Ban white-listed ips, and email alerts.
- SSH key mappings can be configured to automatically allow PKE access to certain user accounts via SSH.
- Access to the server can be restricted to specific users by modifying the `allowed_ssh_users` csv list.
- Whitelisted IPs can be added to the `ip_whitelist` csv list to prevent them from being banned by Fail2Ban.
- Email alerts can be configured by modifying the `sender` and `recipients` variables respectively.

Modify the `config.sh` file so that it looks similar to the following:

```bash
#!/usr/bin/env bash

allowed_ssh_pk_user_mappings="void:ssh-ed25519 AAAA+.......I3tMyotj+jUD>"
allowed_ssh_users="your_user"
ip_whitelist="your_ip/32"
sender="void@your-domain.com.au"
recipients="your-main-email@another-domain.com"

export allowed_ssh_pk_user_mappings allowed_ssh_users ip_whitelist sender recipients
```

If you'd like, you can configure a mail forwarding service to your mail transfer authority so that the toolkits can send alerts and logs, you can use the mail forwarding service installer.
It's set up to install and configure Postfix to forward all mail to your mail transfer authority over SMTP/TLS on port 587. The script will also install the necessary SASL authentication packages and configure the relay with password authentication. Passwords are hashed and stored in `/etc/postfix/sasl_passwd`. All configurations are validated, backed up and timestamped.

```bash
./postfix_forwarding_service_installer.sh my.mail@mailer.com mta.smtp.relay.com
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Package 'sendmail' is not installed, so not removed
0 to upgrade, 0 to newly install, 0 to remove and 0 not to upgrade.
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
postfix is already the newest version (3.6.4-1ubuntu1.3).
libsasl2-modules is already the newest version (2.1.27+dfsg2-3ubuntu1.2).
0 to upgrade, 0 to newly install, 0 to remove and 0 not to upgrade.
Updated sendmail_path in /etc/postfix/main.cf.
Updated mailq_path in /etc/postfix/main.cf.
Updated newaliases_path in /etc/postfix/main.cf.
Updated html_directory in /etc/postfix/main.cf.
Updated manpage_directory in /etc/postfix/main.cf.
Updated sample_directory in /etc/postfix/main.cf.
Updated readme_directory in /etc/postfix/main.cf.
Enter SMTP username: TEST
Enter SMTP password: postmap: name_mask: ipv4
postmap: inet_addr_local: configured 4 IPv4 addresses
postmap: open hash /etc/postfix/sasl_passwd
postmap: Compiled against Berkeley DB: 5.3.28?
postmap: Run-time linked against Berkeley DB: 5.3.28?
● postfix.service - Postfix Mail Transport Agent
     Loaded: loaded (/lib/systemd/system/postfix.service; enabled; vendor preset: enabled)
     Active: active (exited) since Fri 2024-03-01 22:41:53 AEST; 26ms ago
       Docs: man:postfix(1)
    Process: 1469773 ExecStart=/bin/true (code=exited, status=0/SUCCESS)
   Main PID: 1469773 (code=exited, status=0/SUCCESS)
        CPU: 940us

Mar 01 22:41:53 null systemd[1]: Starting Postfix Mail Transport Agent...
Mar 01 22:41:53 null systemd[1]: Finished Postfix Mail Transport Agent.
Validating Postfix configuration...
Postfix configuration is valid.
● postfix.service - Postfix Mail Transport Agent
     Loaded: loaded (/lib/systemd/system/postfix.service; enabled; vendor preset: enabled)
     Active: active (exited) since Fri 2024-03-01 22:41:55 AEST; 22ms ago
       Docs: man:postfix(1)
    Process: 1470205 ExecStart=/bin/true (code=exited, status=0/SUCCESS)
   Main PID: 1470205 (code=exited, status=0/SUCCESS)
        CPU: 931us

Mar 01 22:41:55 null systemd[1]: Starting Postfix Mail Transport Agent...
Mar 01 22:41:55 null systemd[1]: Finished Postfix Mail Transport Agent.
Postfix configuration successfully completed.
```

Directly as a single script
```bash
pwd # /hardening
chmod +x automated_hardening.sh
./automated_hardening.sh
```

Or as a series of individual standalone scripts - note that running this will not configure proper email alerts.  
```bash
cd /hardening/standalones
find . -type f -name '*.sh' -exec sudo bash {} \;
```

To skip the installation of a specific toolkit, you can use the following command: 
```bash
cd /hardening/standalones
find . -type f -name '*.sh' ! -name 'setup_ssh_intrusion_detection.sh' -exec sudo bash {} \; # Skip SSH Intrusion Detection
```**

Or individually - note certain toolkits use commandline arguments to enable email alerts and more specialized use cases.
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
