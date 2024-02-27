#!/usr/bin/env bash

set -euo pipefail

# Main function
main() {
  check_root
  echo "Initializing Auditd..."

  install_apt_packages "auditd"
  configure_audit_rules
  configure_auditd_logging

  status_service "auditd"
  start_service "auditd"
  enable_service "auditd"
  restart_service "auditd"

  view_auditd_config
  show_auditd_aureport

  local script_location="/usr/local/bin/audit-report.sh"
  local log_file="/var/log/audit-report.log"

  write_auditd_reporting "${script_location}"
  update_cron_job "${script_location}" "${log_file}"
}

main "$@"