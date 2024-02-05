#!/usr/bin/env bash

# Source utility functions
source_utility_functions() {
  source standalones/upgrades/setup_auto_upgrades.sh
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

  source standalones/rkhunter/setup_rkhunter.sh
  source standalones/auditd/setup_auditd.sh
  source standalones/lynis/setup_lynis.sh
  source standalones/fail2ban/setup_fail2ban.sh
}

# Main functions
main() {
  source_utility_functions

  # Setup the SSHD IDS
  source standalones/sshd/setup_ssh_intrusion_detection.sh install

  main_auditd_setup
  main_fail2ban_setup
  main_auto_upgrades_setup
  main_rkhunter_setup
  main_lynis_setup

}

main "$@"
