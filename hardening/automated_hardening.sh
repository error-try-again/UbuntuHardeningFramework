#!/usr/bin/env bash

set -euo pipefail

# Main functions
main() {
  source standalones/sshd/setup_ssh_intrusion_detection.sh install
  source standalones/auditd/setup_auditd.sh
  source standalones/fail2ban/setup_fail2ban.sh
  source standalones/upgrades/setup_auto_upgrades.sh
  source standalones/rkhunter/setup_rkhunter.sh
  source standalones/lynis/setup_lynis.sh
  source standalones/firewall/setup_firewall.sh
  source standalones/memory/setup_shared_memory_hardening.sh
  source standalones/networking/setup_network_hardening_parameters.sh
  source standalones/apparmor/setup_apparmor.sh
  source standalones/password/setup_password_policy.sh
  source standalones/sshd/configure_ssh_hardening.sh
}

main "$@"
