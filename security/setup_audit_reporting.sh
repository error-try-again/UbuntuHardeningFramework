#!/usr/bin/env bash

set -euo pipefail

# Log a message to the log file
log() {
  local message="$1"
  local date
  date=$(date +'%Y-%m-%d %H:%M:%S')
  echo "${date} - ${message}" >> "${log_file}"
}

# Generate and output an audit report
generate_aurp_report() {
  local report
  report=$(aureport --summary -i -ts today)
  echo "${report}"
}

# Send a recipient with the audit report using sendmail
send_auditd_report() {
  # Set the recipient address where the report will be sent
  local recipient="$1"
  local sender="$2"
  local mail_tool="$3"
  local subject="$4"
  local report="$5"

  # Check if the report contains relevant information
  if [[ -n ${report} ]]; then
    # Send a recipient with the report using sendmail
    if ! echo -e "Subject: ${subject}\nTo: ${recipient}\nFrom: ${sender}\n\n${report}" | ${mail_tool} -f "${sender}" -t "${recipient}"; then
      log "Error: Failed to send email."
    else
      log "Email sent: ${subject}"
    fi
    log "Audit report sent."
  else
    # If no relevant information found, log a message
    log "No relevant audit information found."
  fi
}

# Main function
main() {
  log_file="/var/log/audit-report.log"
  local sender="example1.eg@example.com"
  local mail_tool="sendmail"

  local hostname subject
  hostname=$(hostname)
  subject="[${hostname}] - [Auditd Review Report] - [$(date +'%Y-%m-%d')]"

  local report
  report="$(generate_aurp_report)"

  # Add Comma separated email addresses of the recipients to the variable
  # Example: "example.eg@example.com,example@gmail.com"
  local recipients="example.eg@example.com"
  send_auditd_report "${recipients}" "${sender}" "${mail_tool}" "${subject}" "${report}"
}

main "$@"
