#!/usr/bin/env bash

set -euo pipefail

# Source utility functions
source_utility_functions() {
  source standalones/util/general/check_root.sh
  source standalones/util/general/ensure_file_is_writable.sh
  source standalones/util/general/create_file_if_not_exists.sh
  source standalones/util/apt/install_apt_packages.sh
  source standalones/util/daemon/enable_service.sh
  source standalones/util/daemon/start_service.sh
  source standalones/util/daemon/status_service.sh
  source standalones/util/daemon/restart_service.sh
  source standalones/util/configure/auditd/configure_audit_rules.sh
  source standalones/util/configure/auditd/configure_auditd_logging.sh
  source standalones/auditd/setup_audit_reporting.sh
  source standalones/util/cron/update_cron_job.sh
  source standalones/util/logging/system_log.sh
  source standalones/util/logging/log_message.sh
  source standalones/util/report/auditd/show_auditd_aureport.sh
  source standalones/util/report/auditd/view_auditd_config.sh
  source standalones/util/report/auditd/write_auditd_reporting.sh
  source standalones/util/configure/fail2ban/create_jail_config.sh
  source standalones/util/backup/backup_jail_config.sh
  source standalones/util/report/fail2ban/view_fail2ban_config.sh
  source standalones/rkhunter/configure_rkhunter.sh
}

# Main functions
main() {
  source_utility_functions

  # Call the standalone scripts to harden the system
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
