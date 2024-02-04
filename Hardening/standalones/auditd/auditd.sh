#!/usr/bin/env bash

declare -g log_file="/var/log/auditd.log"

# Log messages to a log file
log() {
  local message="$1"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - ${message}" >> "${log_file}"
}

# Install Auditd
install_apt_packages() {
  log "Updating package list and installing Auditd."

  # Use which to determine if the package is installed
  command -v auditd &> /dev/null && {
    log "Auditd already installed."
    return
  } || {
    {
      apt update -y && apt install -y auditd
    } || {
      log "Failed to install Auditd."
      exit 1
    }
  }

  log "Auditd installed successfully."
}

# Configure Auditd rules
configure_audit_rules() {
  log "Configuring Auditd rules..."

  # Define custom audit rules
  cat << EOL > /etc/audit/rules.d/custom-audit-rules.rules
# Monitor system changes
-w /etc/passwd -p wa
-w /etc/shadow -p wa
-w /etc/sudoers -p wa
-w /etc/group -p wa

# Monitor login and authentication events
-w /var/log/auth.log -p wa
-w /var/log/secure -p wa

# Monitor executable files
-a always,exit -F arch=b64 -S execve
-a always,exit -F arch=b32 -S execve
EOL

  log "Custom Auditd rules configured."
}

# Configure Auditd logging
configure_auditd_logging() {
  log "Configuring Auditd logging..."
  # Look for the log_format and log_file settings in the auditd.conf file and update them if necessary
  sed -i 's/^log_format =.*/log_format = RAW/g' /etc/audit/auditd.conf
  sed -i 's/^log_file =.*/log_file = \/var\/log\/audit\/audit.log/g' /etc/audit/auditd.conf
  log "Auditd logging configured."
}

# Restart Fail2ban service
restart_fail2ban() {
  log "Restarting Fail2ban service..."
  systemctl restart fail2ban --no-pager
  log "Fail2ban service restarted."
}

# View Auditd service status
view_auditd_status() {
  log "Checking Auditd service status..."
  systemctl status auditd --no-pager
}

# Start Auditd service
start_auditd() {
  log "Starting Auditd service..."
  systemctl start auditd --no-pager
  log "Auditd service started."
}

# Enable Auditd service to start on boot
enable_auditd() {
  log "Enabling Auditd service to start on boot..."
  systemctl enable auditd --no-pager
  log "Auditd service enabled to start on boot."
}

# Restart Auditd service
restart_auditd() {
  log "Restarting Auditd service..."
  systemctl restart auditd --no-pager
  log "Auditd service restarted."
}

# View Auditd configuration
view_auditd_config() {
  log "Viewing Auditd configuration..."
  auditctl -l

  log "Viewing Auditd rules..."
  cat /etc/audit/rules.d/custom-audit-rules.rules

  log "Viewing Auditd configuration..."
  cat /etc/audit/auditd.conf
}

# Show aureport
show_aureport() {
  log "Showing aureport..."
  aureport --summary
}

# Write an audit reporting script
write_audit_reporting_script() {
  local script="$1"

  cat << 'EOF' > "${script}"
#!/usr/bin/env bash

# Log a message to the log file
log() {
  local message="$1"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - ${message}" >> "${log_file}"
}

# Send an email with the audit report using sendmail
review_audit_and_send_report() {
  # Set the email address where the report will be sent
  local email="$1"

  # Set the subject for the email
  local subject
  subject="[$(hostname)] - [Auditd Review Report] - [$(date +'%Y-%m-%d')]"

  # Generate the audit report using aureport
  local report
  report=$(sudo aureport --summary -i -ts today)

  # Check if the report contains relevant information
  if [[ -n "${report}" ]]; then
      # Send an email with the report using sendmail
      echo "${report}" | sendmail -t "${email}" -s "${subject}"
      log "Audit report sent."
  else
      # If no relevant information found, log a message
      log "No relevant audit information found."
  fi
}

# Main function
main() {
  log_file="/var/log/audit-report.log"

  local email="yane.neurogames@gmail.com"
  review_audit_and_send_report "${email}"
}

main "$@"

EOF

  chmod +x "${script}"
  chown root:root "${script}"

  log "Audit reporting script created."
}

# Updates the cron job for a script
update_cron_job() {
  local script="$1"
  local log_file="$2"
  local cron_entry="0 0 * * * ${script} >${log_file} 2>&1"

  local current_cron_job
  current_cron_job=$(crontab -l | grep "${script}")

  if [[ -z ${current_cron_job} ]] || [[ ${current_cron_job} != "${cron_entry}" ]]; then
    (
      crontab -l 2> /dev/null | grep -v "${script}"
                                                         echo "${cron_entry}"
    )                                                                          | crontab -
    echo "Cron job updated."
  else
    echo "Cron job already up to date."
  fi
}

# Check if the script is being run as root
check_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
  fi
}

# Main function
main() {
  check_root
  install_apt_packages
  configure_audit_rules
  configure_auditd_logging
  restart_fail2ban
  view_auditd_status
  start_auditd
  enable_auditd
  restart_auditd
  view_auditd_config
  show_aureport

  local script="/usr/local/bin/audit-report.sh"
  local log_file="/var/log/audit-report.log"

  write_audit_reporting_script "${script}"
  update_cron_job "${script}" "${log_file}"

}

main "$@"
