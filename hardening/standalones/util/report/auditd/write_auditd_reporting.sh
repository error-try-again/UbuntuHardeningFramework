#!/usr/bin/env bash

# Write an audit reporting script_location
write_auditd_reporting() {
  local script_location="$1"

  cp ./standalones/auditd/setup_audit_reporting.sh "${script_location}"

  chmod +x "${script_location}"
  chown root:root "${script_location}"
  chown root:root "${script_location}"

  log "Audit reporting script copied to ${script_location}"
}
