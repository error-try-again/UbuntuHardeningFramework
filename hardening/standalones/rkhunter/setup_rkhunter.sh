#!/usr/bin/env bash

set -euo pipefail

# Checks if the script is being run as root
check_root() {
  local uuid
  uuid=$(id -u)
  if [[ ${uuid} -ne 0 ]]; then
    echo "This script must be run as root. Exiting..." >&2
    exit 1
  fi
}

# Log a message to the log file
log() {
  local message="$1"
  local date
  date=$(date +'%Y-%m-%d %H:%M:%S')
  echo "${date} - ${message}"
}

usage() {
  echo "Usage: $0 <recipient_email_addresses> <sender_email_address>"
  echo "Example: $0 recipient1@ex.com,recipient2@ex.com sender@ex.com"
  exit 1
}

# Installs a list of apt packages
install_apt_packages() {
  local package_list=("${@}") # Capture all arguments as an array of packages

  log "Starting package installation process."

  # Verify that there are no apt locks
  while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
    log "Waiting for other software managers to finish..."
    sleep 1
  done

  if apt update -y; then
    log "Package lists updated successfully."
  else
    log "Failed to update package lists. Continuing with installation..."
  fi

  local package
  local failed_packages=()
  for package in "${package_list[@]}"; do
    if dpkg -l | grep -qw "${package}"; then
      log "${package} is already installed."
    else
      # Sleep to avoid "E: Could not get lock /var/lib/dpkg/lock-frontend" error
      sleep 1
      if apt install -y "${package}"; then
        log "Successfully installed ${package}."
      else
        log "Failed to install ${package}."
        failed_packages+=("${package}")
      fi
    fi
  done

  if [[ ${#failed_packages[@]} -eq 0 ]]; then
    log "All packages were installed successfully."
  else
    log "Failed to install the following packages: ${failed_packages[*]}"
  fi
}

# Configures rkhunter to run daily and email results
configure_rkhunter() {
  local recipients="$1"
  local sender="$2"

  log "Configuring rkhunter..."

  # Modify the UPDATE_MIRRORS and MIRRORS_MODE settings in /etc/rkhunter.conf to enable the use of mirrors
  sed -i -e 's|^[#]*[[:space:]]*UPDATE_MIRRORS=.*|UPDATE_MIRRORS=1|' /etc/rkhunter.conf
  sed -i -e 's|^[#]*[[:space:]]*MIRRORS_MODE=.*|MIRRORS_MODE=0|' /etc/rkhunter.conf

  # Modify the APPEND_LOG setting in /etc/rkhunter.conf to ensure that logs are appended rather than overwritten
  sed -i -e 's|^[#]*[[:space:]]*APPEND_LOG=.*|APPEND_LOG=1|' /etc/rkhunter.conf

  # Modify the USE_SYSLOG setting in /etc/rkhunter.conf to enable the use of syslog integration
  sed -i "s|^USE_SYSLOG=.*|USE_SYSLOG=authpriv.warning|" /etc/rkhunter.conf

  # Modify the WEB_CMD setting in /etc/rkhunter.conf to disable the use of the web command
  sed -i "s|^WEB_CMD=.*|WEB_CMD=|" /etc/rkhunter.conf

  # Use GLOBSTAR to improve comprehensive file pattern matching.
  # sed -i -e 's|^[#]*[[:space:]]*GLOBSTAR=.*|GLOBSTAR=1|' /etc/rkhunter.conf

  # Adjust ENABLE_TESTS and DISABLE_TESTS to enable all tests
  sed -i -e 's|^[#]*[[:space:]]*ENABLE_TESTS=.*|ENABLE_TESTS=ALL|' /etc/rkhunter.conf
  sed -i -e 's|^[#]*[[:space:]]*DISABLE_TESTS=.*|DISABLE_TESTS=None|' /etc/rkhunter.conf

  # set the default installer values so that
  echo "rkhunter rkhunter/apt_autogen boolean true" | debconf-set-selections
  echo "rkhunter rkhunter/cron_daily_run boolean true" | debconf-set-selections
  echo "rkhunter rkhunter/cron_db_update boolean true" | debconf-set-selections

  # use dpkg-reconfigure using debian standard packaging with non-interactive mode
  dpkg-reconfigure debconf -f noninteractive

  # Modify /etc/default/rkhunter to enable daily runs and database updates
  sed -i -e 's|^[#]*[[:space:]]*CRON_DAILY_RUN=.*|CRON_DAILY_RUN="true"|' /etc/default/rkhunter # enable daily runs
  sed -i -e 's|^[#]*[[:space:]]*CRON_DB_UPDATE=.*|CRON_DB_UPDATE="true"|' /etc/default/rkhunter # enable database updates
  sed -i -e 's|^[#]*[[:space:]]*APT_AUTOGEN=.*|APT_AUTOGEN="true"|' /etc/default/rkhunter # enable automatic updates

  # Email settings for rkhunter
  sed -i -e 's|^[#]*[[:space:]]*REPORT_EMAIL=.*|REPORT_EMAIL="'"${recipients}"'"|' /etc/default/rkhunter # set the email recipient
  sed -i -e 's|^[#]*[[:space:]]*DB_UPDATE_EMAIL=.*|DB_UPDATE_EMAIL="true"|' /etc/default/rkhunter # enable database update emails

  # Set the sender email for rkhunter if it doesn't exist
  grep -qE "^REPORT_SENDER=" /etc/default/rkhunter || { echo "# Report sender email" >> /etc/default/rkhunter && echo "REPORT_SENDER=\"${sender}\"" >> /etc/default/rkhunter; }

  # Replace the sender if it exists in the file
  sed -i -e 's|^[[:space:]]*#*\s*REPORT_SENDER=.*|REPORT_SENDER="'"${sender}"'"|' /etc/default/rkhunter # Replace the sender email if it exists

  log "rkhunter has been configured successfully at /etc/default/rkhunter and /etc/rkhunter.conf"
}

write_rkhunter_weekly() {
  echo "Writing rkhunter weekly cron job at /etc/cron.weekly/rkhunter"

  local rk_weekly="/etc/cron.weekly/rkhunter"

  cat <<'EOF' > "${rk_weekly}"
#!/usr/bin/env bash

# Log messages with appropriate prefixes
system_log() {
  local log_type="$1"
  local message="$2"
  local log_file="$3"
  local date
  date=$(date '+%Y-%m-%d %H:%M:%S')
  echo "${date} - ${log_type}: ${message}" | tee -a "${log_file}"
}

# Checks if the script is being run as root
check_root() {
  local uuid
  uuid=$(id -u)
  if [[ ${uuid} -ne 0 ]]; then
    echo "This script must be run as root. Exiting..." >&2
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

  local mail_tool="sendmail"

  local hostname
  hostname=$(hostname -f)

  if [[ -z ${recipient} ]]; then
    system_log "ERROR" "Email recipient not specified." "${log_file}"
    return 1
  fi

  if ! echo -e "Subject: ${subject}\nTo: ${recipient}\nFrom: ${REPORT_SENDER}\n\n${content}" | ${mail_tool} -f "${REPORT_SENDER}" -t "${recipient}"; then
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
    hostname=$(hostname -f)

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

EOF

  chmod +x /etc/cron.weekly/rkhunter

  log "rkhunter cron jobs have been written successfully at /etc/cron.weekly/rkhunter"
  log "Attempting to perform a weekly rkhunter database update..."

  "${rk_weekly}"

}

write_rkhunter_daily() {
  echo "Writing rkhunter daily cron job at /etc/cron.daily/rkhunter"

  local rk_daily="/etc/cron.daily/rkhunter"

  cat <<'EOF' > "${rk_daily}"
#!/usr/bin/env bash

# Log messages with appropriate prefixes
system_log() {
  local log_type="$1"
  local message="$2"
  local log_file="$3"
  local date
  date=$(date '+%Y-%m-%d %H:%M:%S')
  echo "${date} - ${log_type}: ${message}" | tee -a "${log_file}"
}

# Checks if the script is being run as root
check_root() {
  local uuid
  uuid=$(id -u)
  if [[ ${uuid} -ne 0 ]]; then
    echo "This script must be run as root. Exiting..." >&2
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

  local mail_tool="sendmail"

  local hostname
  hostname=$(hostname -f)

  if [[ -z ${recipient} ]]; then
    system_log "ERROR" "Email recipient not specified." "${log_file}"
    return 1
  fi

  if ! echo -e "Subject: ${subject}\nTo: ${recipient}\nFrom: ${REPORT_SENDER}\n\n${content}" | ${mail_tool} -f "${REPORT_SENDER}" -t "${recipient}"; then
    system_log "ERROR" "Failed to send email." "${log_file}"
  else
    system_log "INFO" "Email sent: ${subject}" "${log_file}"
  fi
}

# Handle the daily rkhunter run and send an email if there are warnings
handle_updates() {
  local rkhunter="$1"
  local recipient="$2"
  local report_file="$3"

  # Set default nice value if not set
  local nice=${nice:-0}

  # Check if CRON_DAILY_RUN is set and proceed if it's true
  if [[ ${CRON_DAILY_RUN} =~ [YyTt]* ]]; then
    system_log "INFO" "Starting rkhunter daily run..." "${log_file}"
    /usr/bin/nice -n "${nice}" "${rkhunter}" --cronjob --report-warnings-only --appendlog > "${report_file}" 2>&1

    local report_content
    local hostname

    report_content=$(cat "${report_file}")
    hostname=$(hostname -f)

    local report_date
    report_date=$(date '+%Y-%m-%d')

    local subject
    subject="[rkhunter] - [${hostname}] - [Daily Report] - [$(date '+%Y-%m-%d %H:%M')]"

    send_email "${subject}" "${report_content}" "${recipient}"
    system_log "INFO" "Daily report email sent." "${log_file}"
  else
    system_log "ERROR" "CRON_DAILY_RUN is not set to true. Exiting." "${log_file}"
    exit 0
  fi
}

# Main function
main() {
  check_root

  # Source config
  . /etc/default/rkhunter

  log_file="/var/log/rkhunter.log"
  report_file="/tmp/rkhunter_report.log"

  local rkhunter="rkhunter"
  local mta="sendmail"

  # Check if rkhunter is installed and executable
  ensure_command_is_executable "${rkhunter}"
  ensure_command_is_executable "${mta}"

  create_file_if_not_exists "${log_file}"
  create_file_if_not_exists "${report_file}"

  # Handle the daily rkhunter run
  handle_updates "${rkhunter}" "${REPORT_EMAIL}" "${report_file}"
}

main "$@"
EOF

  chmod +x /etc/cron.daily/rkhunter

  log "rkhunter cron jobs have been written successfully at /etc/cron.weekly/rkhunter and /etc/cron.daily/rkhunter"
  log "Attempting to perform a daily rkhunter run..."
  ${rk_daily}
}

# Main function
main() {
  check_root
  echo "Initializing rkhunter..."

  local recipients="${1:-root@$(hostname -f)}" # Default recipient email if not provided
  local sender="${2:-root@$(hostname -f)}" # Default sender email if not provided

  install_apt_packages "debconf-utils" "rkhunter"
  configure_rkhunter "${recipients}" "${sender}"
  write_rkhunter_weekly
  write_rkhunter_daily
}

main "$@"