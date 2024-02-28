#!/usr/bin/env bash

set -euo pipefail

# Ensures the script is executed with root privileges. Exits if not.
check_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
  fi
}

# Set a strong password policy
configure_password_policy() {
  echo "Configuring password policy..."
  sudo apt-get install libpam-pwquality -y || {
                                                echo "Failed to install libpam-pwquality"
                                                exit 1
  }

  # Ensure pwquality.conf settings are not duplicated
  grep -q "^minlen = 24" /etc/security/pwquality.conf || sudo sed -i '/^minlen = /c\minlen = 24' /etc/security/pwquality.conf
  grep -q "^retry = 3" /etc/security/pwquality.conf || sudo sed -i '/^retry = /c\retry = 3' /etc/security/pwquality.conf
  grep -q "^dcredit = -1" /etc/security/pwquality.conf || sudo sed -i '/^dcredit = /c\dcredit = -1' /etc/security/pwquality.conf
  grep -q "^ucredit = -1" /etc/security/pwquality.conf || sudo sed -i '/^ucredit = /c\ucredit = -1' /etc/security/pwquality.conf
  grep -q "^ocredit = -1" /etc/security/pwquality.conf || sudo sed -i '/^ocredit = /c\ocredit = -1' /etc/security/pwquality.conf
  grep -q "^lcredit = -1" /etc/security/pwquality.conf || sudo sed -i '/^lcredit = /c\lcredit = -1' /etc/security/pwquality.conf

  # Ensure ENCRYPT_METHOD SHA256 is not duplicated
  grep -q "^ENCRYPT_METHOD SHA256" /etc/login.defs || sudo sed -i '/^ENCRYPT_METHOD /c\ENCRYPT_METHOD SHA256' /etc/login.defs

  # Configure PAM to enforce the password policy with obscure checks, ensuring no duplication
  local pam_pwquality_line="password requisite pam_pwquality.so retry=3 minlen=24 dcredit=-1 ucredit=-1 ocredit=-1 lcredit=-1"
  if ! grep -q "${pam_pwquality_line}" /etc/pam.d/common-password; then
    sudo sed -i "/^password.*pam_unix.so/ s/$/ ${pam_pwquality_line}/" /etc/pam.d/common-password
  fi

  echo "Password policy configured."
}


# Main function
main() {
  check_root
  configure_password_policy
}

main "$@"