#!/usr/bin/env bash

# Configure SSH Hardening
configure_ssh_hardening() {

  # Backup the original sshd_config file
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup$(date +%F-%T)

  # Variables for configuration
  local allow_users_list="admin" # Space-separated list of users allowed to login via SSH
  local ssh_port="6911" # Changing to a non-standard port reduces exposure to automated attacks

  echo "Applying secure configurations to SSH..."

  # Basic Configuration
  # -------------------
  ufw allow "${ssh_port}" # Allow the new SSH port through the firewall
  sed -i "s|^#Port 22|Port ${ssh_port}|" /etc/ssh/sshd_config # Change SSH port to a non-standard port

  # Authentication Configuration
  # ----------------------------
  sed -i 's|^#PermitRootLogin .*$|PermitRootLogin no|' /etc/ssh/sshd_config # Disable root login
  sed -i 's|^#PubkeyAuthentication .*$|PubkeyAuthentication yes|' /etc/ssh/sshd_config # Enforce public key authentication
  sed -i 's|^#PermitEmptyPasswords .*$|PermitEmptyPasswords no|' /etc/ssh/sshd_config # Disable empty passwords
  sed -i 's|^#ChallengeResponseAuthentication .*$|ChallengeResponseAuthentication no|' /etc/ssh/sshd_config # Disable challenge-response authentication

  #     Uncomment the following line to disable password authentication for root (post-key setup)
  sed -i 's|^#PasswordAuthentication .*$|PasswordAuthentication no|' /etc/ssh/sshd_config # Disable password authentication

  # Ensure PAM is enabled for better security, used for advanced authentication and session management
  # sed -i 's|^UsePAM no$|UsePAM yes|' /etc/ssh/sshd_config

  # Security Enhancements
  # ----------------------
  sed -i 's|^X11Forwarding yes$|X11Forwarding no|' /etc/ssh/sshd_config # Disable X11 forwarding
  sed -i 's|^#UseDNS .*$|UseDNS no|' /etc/ssh/sshd_config # Disable DNS lookup to speed up connections

  # Connection and Session Management
  # ---------------------------------
  sed -i 's|^LoginGraceTime 2m$|LoginGraceTime 30s|' /etc/ssh/sshd_config # Reduce login grace time
  sed -i 's|^MaxAuthTries 6$|MaxAuthTries 2|' /etc/ssh/sshd_config # Reduce max auth attempts
  echo -e "ClientAliveInterval 120\nClientAliveCountMax 0" >> /etc/ssh/sshd_config # Set aggressive session timeout

  # Advanced Security Settings
  # ---------------------------
  echo "AllowUsers ${allow_users_list}" >> /etc/ssh/sshd_config # Limit user login

  # Set secure key exchange, encryption, and MAC algorithms
  #  echo -e "KexAlgorithms curve25519-sha256@libssh.org\nCiphers aes256-ctr,aes192-ctr,aes128-ctr\nMACs hmac-sha2-512,hmac-sha2-256" >> /etc/ssh/sshd_config

  # Disable unused features for increased security (if not already disabled)
  # Dependent on your use case, e.g. if you need port forwarding for some reason, you should not disable it here
  sed -i 's|^#AllowAgentForwarding yes$|AllowAgentForwarding no|' /etc/ssh/sshd_config
  sed -i 's|^#AllowTcpForwarding yes$|AllowTcpForwarding no|' /etc/ssh/sshd_config
  sed -i 's|^#PermitTTY yes$|PermitTTY no|' /etc/ssh/sshd_config
  sed -i 's|^#Compression delayed$|Compression no|' /etc/ssh/sshd_config

  # Harden HostKeys with secure algorithms
  sed -i 's|^#HostKey /etc/ssh/ssh_host_rsa_key$|HostKey /etc/ssh/ssh_host_ed25519_key|' /etc/ssh/sshd_config # Use Ed25519 for host keys (preferred)
  sed -i 's|^#HostKey /etc/ssh/ssh_host_ecdsa_key$|HostKey /etc/ssh/ssh_host_rsa_key|' /etc/ssh/sshd_config # Use RSA for host keys (fallback)

  # Restart sshd to apply changes
#  systemctl restart sshd

  echo "SSH hardening configuration applied successfully."
}

# Main function
main() {
  # Ensure that the script is run as root
  if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
  fi

  configure_ssh_hardening
}

main "$@"
