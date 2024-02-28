#!/usr/bin/env bash

set -euo pipefail

# Ensures the script is executed with root privileges. Exits if not.
check_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
  fi
}

# Check for the availability of required commands before proceeding
check_required_commands() {
  local missing_commands=0
  local cmd
  for cmd in apt-get systemctl aa-enforce auditctl; do
    if ! command -v "${cmd}" &> /dev/null; then
      echo "Required command ${cmd} is not available."
      ((missing_commands++))
    fi
  done

  if ((missing_commands > 0)); then
    echo "Some required commands are missing. Please ensure your system has apt-get, systemctl, aa-enforce, and auditctl available."
    exit 1
  fi
}

# Installs and configures AppArmor if it is not already active.
install_and_configure_apparmor() {
  if systemctl is-active --quiet apparmor; then
    echo "AppArmor is already active and running."
  else
    echo "Installing and activating AppArmor..."
    if apt-get update && apt-get install apparmor apparmor-utils -y && systemctl enable apparmor && systemctl start apparmor; then
      echo "AppArmor installed and activated successfully."
    else
      echo "Failed to install or activate AppArmor. Please check for errors above."
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
    echo "Failed to set some profiles to enforce mode. Check for errors above."
  fi
  echo "Current status of AppArmor profiles:"
  aa-status
}

# Enable Auditing for AppArmor
enable_apparmor_auditing() {
  echo "Enabling auditing for AppArmor..."
  {
    echo "-w /etc/apparmor/ -p wa -k apparmor"
    echo "-w /etc/apparmor.d/ -p wa -k apparmor"
  } >> /etc/audit/audit.rules && systemctl restart auditd && echo "Auditing for AppArmor enabled."
}

# Main function
main() {
  check_root
  check_required_commands
  install_and_configure_apparmor
  enforce_apparmor_profiles
  enable_apparmor_auditing
}

main "$@"
