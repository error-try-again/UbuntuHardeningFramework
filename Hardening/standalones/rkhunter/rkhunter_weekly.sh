#!/usr/bin/env bash

# Checks whether the script is run as root
check_for_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
  fi
}

# Checks whether a command is executable
check_executability() {
  local command="$1"
  if ! [[ -x "$(command -v "${command}")" ]]; then
    log_message "Error: ${command} not found or not executable."
    exit 1
  fi
}

# Create a file if it doesn't exist
create_file_if_not_exists() {
  local file="$1"
  if ! [[ -f ${file}   ]]; then
    touch "${file}"
    if ! [[ -f ${file}   ]]; then
      log_message "Error: Failed to create file ${file}."
      exit 1
    fi
  fi
}

# Add a timestamp to the log message and print it to stdout and the log file
log_message() {
    local date
    date=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${date}] $1" | tee -a "${log_file}"
}

# Send an email with the given subject and content to the given recipient
send_email() {
  local subject="$1"
  local content="$2"
  local recipient="$3"

  local mail_tool="sendmail"

  local hostname
  hostname=$(hostname)

  if [[ -z ${recipient} ]]; then
    log_message "Error: Email recipient not specified."
    return 1
  fi

  if ! echo -e "Subject: ${subject}\nTo: ${recipient}\nFrom: ${recipient}\n\n${content}" | ${mail_tool} -f "${recipient}" -t "${recipient}"; then
    log_message "Error: Failed to send email."
  else
    log_message "Email sent: ${subject}"
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
  log_message "Error: No tool to download rkhunter updates was found. Please install wget, curl, (e)links or lynx."
  return 1
}

# Handle rkhunter database updates
handle_updates() {
  local rkhunter_path="$1"
  local recipient="$2"
  local report_file="$3"

  check_for_web_tools || exit 1

  if [[ ${DB_UPDATE_EMAIL} =~ [YyTt]   ]]; then
    log_message "Weekly rkhunter database update started"
    "${rkhunter_path}" --versioncheck --nocolors --appendlog > "${report_file}" 2>&1
    "${rkhunter_path}" --update --nocolors --appendlog > "${report_file}" 2>&1

    local report_content
    local hostname

    report_content=$(cat "${report_file}")
    hostname=$(hostname)

    local report_date
    report_date=$(date '+%Y-%m-%d')

    local subject
    subject="[rkhunter] - [${hostname}] - [Weekly Report] - [$(date '+%Y-%m-%d %H:%M')]"

    send_email "${subject}" "${report_content}" "${recipient}"
  else
    log_message "DB_UPDATE_EMAIL is not set to true. Exiting."
    exit 0
  fi
}

# Main function
main() {
  check_for_root

  . /etc/default/rkhunter

  log_file="/var/log/rkhunter.log"
  report_file="/tmp/rkhunter_weekly_report.log"

  local rkhunter_path
  rkhunter_path=$(command -v rkhunter)

  # Check if rkhunter is installed and executable
  check_executability "${rkhunter_path}"
  check_executability "sendmail"

  create_file_if_not_exists "${log_file}"
  create_file_if_not_exists "${report_file}"

  # Run handle_updates if configured to do so in cron
  [[ ${CRON_DB_UPDATE} =~ [YyTt] ]] && handle_updates "${rkhunter_path}" "${REPORT_EMAIL}" "${report_file}"
}

main "$@"
