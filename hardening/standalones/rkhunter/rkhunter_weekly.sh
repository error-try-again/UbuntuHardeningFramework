#!/usr/bin/env bash

# Log messages with appropriate prefixes
system_log() {
  local log_type="$1"
  local message="$2"
  local log_file="$3"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ${log_type}: ${message}" | tee -a "${log_file}"
}

# Checks if the script is being run as root (used for apt)
check_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "Please run as root"
    exit 1
  fi
}

# Ensure command can execute
ensure_command_is_executable() {
  local command="$1"
  if ! [[ -x "$(command -v "${command}")" ]]; then
    system_log "ERROR" "${command} not found or not executable." "${log_file}"
    exit 1
  fi
}

# Ensure that a file exists
create_file_if_not_exists() {
  local file="$1"
  if [[ ! -f ${file} ]]; then
    touch "${file}" || {
      system_log "ERROR" "Unable to create file: ${file}" "${log_file}"
      exit 1
    }
  fi
}

# Send an email with the given subject and content to the given recipient
send_email() {
  local subject="$1"
  local content="$2"
  local recipient="$3"

  local sender
  sender="example1.eg@example.com"

  local mail_tool="sendmail"

  local hostname
  hostname=$(hostname)

  if [[ -z ${recipient} ]]; then
    system_log "ERROR" "Email recipient not specified." "${log_file}"
    return 1
  fi

  if ! echo -e "Subject: ${subject}\nTo: ${recipient}\nFrom: ${sender}\n\n${content}" | ${mail_tool} -f "${sender}" -t "${recipient}"; then
    system_log "ERROR" "Failed to send email." "${log_file}"
  else
    system_log "INFO" "Email sent: ${subject}" "${log_file}"
  fi
}

# Check for the presence of web tools required for downloading updates
check_for_web_tools() {
  local web_tools=(wget curl links elinks lynx)
  local tool
  for tool in "${web_tools[@]}"; do
    if [[ -x "$(command -v "${tool}")" ]]; then
      return 0
    fi
  done
  echo "Error: No tool to download rkhunter updates was found. Please install wget, curl, (e)links or lynx."
  return 1
}

# Handle rkhunter database updates
handle_updates() {
  local rkhunter="$1"
  local recipient="$2"
  local report_file="$3"

  check_for_web_tools || exit 1

  if [[ ${DB_UPDATE_EMAIL} =~ [YyTt]   ]]; then
    system_log "INFO" "Weekly rkhunter database update started" "${log_file}"
    "${rkhunter}" --versioncheck --nocolors --appendlog > "${report_file}" 2>&1
    "${rkhunter}" --update --nocolors --appendlog > "${report_file}" 2>&1

    local report_content
    local hostname

    report_content=$(cat "${report_file}")
    hostname=$(hostname)

    local report_date
    report_date=$(date '+%Y-%m-%d')

    local subject
    subject="[rkhunter] - [${hostname}] - [Weekly Report] - [$(date '+%Y-%m-%d %H:%M')]"

    send_email "${subject}" "${report_content}" "${recipient}"
    system_log "INFO" "Weekly report email sent." "${log_file}"
  else
    system_log "ERROR" "DB_UPDATE_EMAIL is not set to true. Exiting." "${log_file}"
    exit 0
  fi
}

# Main function
main() {
  check_root

  # Source config
  . /etc/default/rkhunter

  log_file="/var/log/rkhunter.log"
  report_file="/tmp/rkhunter_weekly_report.log"

  local rkhunter="rkhunter"
  local mta="sendmail"

  # Check if rkhunter is installed and executable
  ensure_command_is_executable "${rkhunter}"
  ensure_command_is_executable "${mta}"

  create_file_if_not_exists "${log_file}"
  create_file_if_not_exists "${report_file}"

  # Run handle_updates if configured to do so in cron
  [[ ${CRON_DB_UPDATE} =~ [YyTt] ]] && handle_updates "${rkhunter}" "${REPORT_EMAIL}" "${report_file}"
}

main "$@"
