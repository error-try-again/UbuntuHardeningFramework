#!/usr/bin/env bash

# Set a strong password policy
configure_password_policy() {
  echo "Configuring password policy..."
  sudo apt-get install libpam-pwquality -y || {
                                                echo "Failed to install libpam-pwquality"
                                                                                           exit 1
  }

  # Configure password quality requirements
  sudo sed -i '/^minlen = /c\minlen = 24' /etc/security/pwquality.conf
  sudo sed -i '/^retry = /c\retry = 3' /etc/security/pwquality.conf
  sudo sed -i '/^dcredit = /c\dcredit = -1' /etc/security/pwquality.conf
  sudo sed -i '/^ucredit = /c\ucredit = -1' /etc/security/pwquality.conf
  sudo sed -i '/^ocredit = /c\ocredit = -1' /etc/security/pwquality.conf
  sudo sed -i '/^lcredit = /c\lcredit = -1' /etc/security/pwquality.conf

  # Ensure SHA256 is used for password hashing
  sudo sed -i '/^ENCRYPT_METHOD /c\ENCRYPT_METHOD SHA256' /etc/login.defs

  # Configure PAM to enforce the password policy with obscure checks
  local pam_pwquality_line="password requisite pam_pwquality.so retry=3 minlen=24 dcredit=-1 ucredit=-1 ocredit=-1 lcredit=-1"
  sudo sed -i "/^password.*pam_unix.so/ s/$/ ${pam_pwquality_line}/" /etc/pam.d/common-password

  echo "Password policy configured."
}

# Main function
main() {
  configure_password_policy
}

main "$@"