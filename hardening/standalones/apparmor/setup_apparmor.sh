#!/usr/bin/env bash

set -euo pipefail

# Ensures the script is executed with root privileges. Exits if not.
check_root() {
  local uuid
  uuid=$(id -u)
  if [[ ${uuid} -ne 0 ]]; then
    echo "This script must be run as root. Exiting..." >&2
    exit 1
  fi
}

# Installs and configures AppArmor if it is not already active.
install_and_configure_apparmor() {
  if systemctl is-active --quiet apparmor; then
    echo "AppArmor is already active and running. Skipping apt installation."
  else
    echo "Installing and activating AppArmor..."
    if apt-get update -y \
                      && apt-get install -y apparmor apparmor-utils apparmor-notify apparmor-profiles apparmor-profiles-extra \
                                               && systemctl enable apparmor \
                               && systemctl start apparmor; then
      echo "AppArmor installed and activated successfully."
    else
      echo "Failed to install or activate AppArmor."
      exit 1
    fi
  fi
}

# Enforces AppArmor profiles and adds more coverage
enforce_apparmor_profiles() {
  echo "Setting all AppArmor profiles to enforce mode..."
  if aa-enforce /etc/apparmor.d/* &> /dev/null; then
    echo "All AppArmor profiles set to enforce mode."
  else
    echo "Failed to set some profiles to enforce mode."
  fi
  echo "Current status of AppArmor profiles:"
  aa-status
}

# Enable Auditing for AppArmor
enable_apparmor_auditing() {
  local auditd_installed
  auditd_installed=$(command -v auditd)

  if [[ -n "${auditd_installed}" ]]; then
    echo "Auditd is already installed. Skipping installation."
  else
    echo "Installing auditd..."
    if apt-get update -y && apt-get install -y auditd; then
      echo "Auditd installed successfully."
    else
      echo "Failed to install auditd."
      exit 1
    fi
  fi

  echo "Enabling auditd for AppArmor..."
  {
    echo "-w /etc/apparmor/ -p wa -k apparmor"
    echo "-w /etc/apparmor.d/ -p wa -k apparmor"
  } >> /etc/audit/audit.rules && systemctl restart auditd && echo "Auditing for AppArmor enabled."
}

# Main function
main() {
  check_root
  install_and_configure_apparmor
  enforce_apparmor_profiles
  enable_apparmor_auditing
}

main "$@"
