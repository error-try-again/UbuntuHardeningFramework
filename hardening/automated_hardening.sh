#!/usr/bin/env bash

# Enforce strict mode for bash scripting to catch errors early
set -euo pipefail

# Executes a series of hardening scripts that require preconfiguration.
# SC2154 (variable undefined) is a false positive. The variables are defined in the specified configuration file.
# shellcheck disable=SC2154
preconfigured_hardening_scripts() {
  # Setup auditd for system auditing
  source standalones/auditd/setup_auditd.sh "${recipients}" "${sender}"

  # Setup AppArmor in enforcing mode - requires auditd to be installed
  source standalones/apparmor/setup_apparmor.sh

  # Enable and configure fail2ban
  source standalones/fail2ban/setup_fail2ban.sh "${ssh_port}" "${recipients}" "${sender}" "${ip_whitelist}"

  # Setup automatic system updates
  source standalones/upgrades/setup_auto_upgrades.sh "${recipients}" "${sender}"

  # Configure SSH hardening
  source standalones/sshd/configure_ssh_hardening.sh "${allowed_ssh_pk_user_mappings}" "${allowed_ssh_users}" "${ssh_port}"

  # Setup firewall using UFW (Uncomplicated Firewall)
  source standalones/firewall/setup_firewall.sh "${ssh_port}"

  # Setup SSH intrusion detection
  source standalones/sshd/setup_ssh_intrusion_detection.sh install "${recipients}"

  # Setup rkhunter for rootkit detection
  source standalones/rkhunter/setup_rkhunter.sh "${recipients}" "${sender}"

  # Setup lynis for comprehensive system auditing
  source standalones/lynis/setup_lynis.sh "${recipients}" "${sender}"
}

# Executes a series of standalone hardening scripts that do not require preconfiguration.
standalone_hardening_scripts() {
  # Harden shared memory configuration
  source standalones/memory/setup_shared_memory_hardening.sh

  # Harden network parameters for the system
  source standalones/networking/setup_network_hardening_parameters.sh

  # Configure password policy using libpam-pwquality
  source standalones/password/setup_password_policy.sh
}

# Calls functions to execute all preconfigured and standalone hardening scripts.
all_hardening_scripts() {
  preconfigured_hardening_scripts
  standalone_hardening_scripts
}

configuration_warning() {
    echo "Error: No configuration file found. Running standalone hardening scripts only..."
    echo "Preconfigured hardening scripts that require additional configuration are skipped:"
    echo "  - auditd"
    echo "  - apparmor"
    echo "  - fail2ban"
    echo "  - upgrades"
    echo "  - sshd"
    echo "  - rkhunter"
    echo "  - lynis"
}

# Sources the configuration file if present, then runs all preconfigured and standalone hardening scripts.
# If the configuration file is missing, it skips preconfigured scripts and only runs standalone scripts.
# TODO: Adjust cases to handle being run from arbitrary directories
main() {
  if [[ -f configs/config.sh ]]; then
    echo "Configuration file found. Running all hardening scripts..."
    source configs/config.sh
    all_hardening_scripts
    echo "All hardening scripts completed."
  else
    configuration_warning
    standalone_hardening_scripts
    echo "Standalone hardening scripts completed."
    echo "Please restart the system to apply all changes as certain hardening scripts require a reboot to take effect."
  fi
}

# Invoke the main function and pass all positional parameters to it
main "$@"


