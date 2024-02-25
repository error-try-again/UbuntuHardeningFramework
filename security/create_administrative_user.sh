#!/usr/bin/env bash

# Display script usage information
show_help() {
  echo "Usage: ${0} <username>"
  echo
  echo "This script performs the following actions:"
  echo "1. Installs and configures libpam-pwquality for strong password enforcement, including obscure checks and SHA256 hashing."
  echo "2. Creates an administrative user with sudo privileges."
  echo "3. Sets up SSH key-based authentication for the created user."
  echo
  echo "Arguments:"
  echo "  username    The username of the administrative user to be created."
}

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
  sudo sed -i "/^password.*pam_unix.so/ s/$/ $pam_pwquality_line/" /etc/pam.d/common-password

  echo "Password policy configured."
}

# Create an administrative user
create_administrative_user() {
  local user=${1}

  echo "Creating administrative user '${user}'..."
  if sudo -S adduser "${user}" && sudo -S usermod -aG sudo "${user}"; then
    echo "${user} has been added to the sudo group."
  else
    echo "Failed to create administrative user '${user}'. Exiting."
    exit 1
  fi
}

# Initialize SSH key-based authentication
setup_ssh_key_authentication() {
  local user=${1}
  local user_home
  user_home=$(getent passwd "${user}" | cut -d: -f6)  # Get the home directory of the user

  echo "Setting up SSH key authentication for '${user}'..."
  sudo -S mkdir -p "${user_home}/.ssh"
  sudo -S touch "${user_home}/.ssh/authorized_keys"
  sudo -S chmod 700 "${user_home}/.ssh"
  sudo -S chmod 600 "${user_home}/.ssh/authorized_keys"
  sudo -S chown -R "${user}:${user}" "${user_home}/.ssh"

  echo "SSH key authentication setup for ${user}."
}

main() {
  if [[ $# -ne 1   ]]; then
    show_help
    exit 1
  fi

  local user=${1}

  # Enforce strong password policies
  configure_password_policy

  # Create an administrative user
  create_administrative_user "${user}"

  # Setup SSH key-based authentication for the user
  setup_ssh_key_authentication "${user}"
}

main "${@}"

# To set up SSH access while root access is still enabled perform the following:
# ssh -v -i ~/.ssh/ssd-nodes root@208.87.135.31 "cat >> /home/void/.ssh/authorized_keys" < "/home/void/.ssh/ssd-nodes.pub" 2>/dev/null
