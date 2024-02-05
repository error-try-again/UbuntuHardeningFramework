#!/usr/bin/env bash

# Configure Auditd logging
configure_auditd_logging() {
  log "Configuring Auditd logging..."
  # Look for the log_format and log_file settings in the auditd.conf file and update them if necessary
  sed -i 's/^log_format =.*/log_format = RAW/g' /etc/audit/auditd.conf
  sed -i 's/^log_file =.*/log_file = \/var\/log\/audit\/audit.log/g' /etc/audit/auditd.conf
  log "Auditd logging configured."
}
