#!/usr/bin/env bash

# Enable and start a service
enable_service() {
  local service_name="$1"
  systemctl enable "${service_name}" --no-pager
}

# Start a service
start_service() {
  local service_name="$1"
  systemctl start "${service_name}" --no-pager
}

# Checks if the script is being run as root (used for apt)
check_root() {
  if [[ ${EUID} -ne 0   ]]; then
    echo "Please run as root"
    exit 1
  fi
}

# Ensure that a file is writeable
verify_file_is_writable() {
  local file="$1"
  local error_log_file="$2"

  if [[ ! -w ${file} ]]; then
    ssh_system_log "ERROR" "File is not writable: ${file}" "${error_log_file}"
    exit 1
  fi
}

# Ensure that a file exists
check_and_create_file() {
  local file="$1"
  local error_log_file="$2"
  if [[ ! -f ${file} ]]; then
    touch "${file}" || {
      ssh_system_log "ERROR" "Unable to create file: ${file}" "${error_log_file}"
      exit 1
    }
  fi
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

# Log messages with appropriate prefixes
ssh_system_log() {
  local log_type="$1"
  local message="$2"
  local log_file="$3"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ${log_type}: ${message}" | tee -a "${log_file}"
}

# Send email with throttling
send_email_with_throttle() {
  local mail_subject="${1}"
  local message="${2}"
  local alert_email="${3}"
  local last_email_sent_file="${4}"

  local current_time
  current_time=$(date '+%s')

  # Read the last email sent time from file
  local last_email_sent_time
  last_email_sent_time=$(cat "${last_email_sent_file}" 2> /dev/null || echo "")

  # Calculate the time elapsed since the last email was sent
  local time_elapsed=$((current_time - last_email_sent_time))

  if [[ -z ${last_email_sent_time} || ${time_elapsed} -ge 150 ]]; then
    {
      echo -e "Subject: [${mail_subject}] - [$(hostname)] - [$(date '+%Y-%m-%d %H:%M')] \nTo: ${alert_email}\n\n${message}"
    } | sendmail -t || {
      ssh_system_log "ERROR" "Alert mail could not be sent."
    }

    # Update the last email sent time
    last_email_sent_time="${current_time}"
    echo "${last_email_sent_time}" > "${last_email_sent_file}"
    ssh_system_log "INFO" "Sent an alert email."
  else
    ssh_system_log "INFO" "Throttling email. Not sending another alert yet."
  fi
}

# Initialize variables
initialize_variables() {
  last_email_sent_file="/tmp/last_email_sent_time"
  last_check_file="/tmp/last_ssh_check"

  error_log_file="/var/log/ssh_monitor_error.log"
  default_alert_email="yane.karov@gmail.com"
  default_alert_threshold=1
  default_mail_subject="SSH Monitor Alert"

  service_file="/etc/systemd/system/ssh_monitor.service"
  service_name="ssh_monitor.service"
  service_description="SSH Monitor Service"

  script_dir=$(dirname "$(readlink -f "$0")")
  local_config_file="${script_dir}/ssh_monitor_config"

  local default_log_file="/var/log/ssh_monitor.log"
  log_file="${default_log_file}"

  alert_email="${default_alert_email}"
  alert_threshold="${default_alert_threshold}"
  mail_subject="${default_mail_subject}"
}

# Load configuration from the local config file
load_config() {
  local local_config_file="$1"
  local log_file="$2"
  local error_log_file="$3"
  local default_alert_email="$4"
  local default_alert_threshold="$5"
  local default_mail_subject="$6"

  if [[ -f ${local_config_file} ]]; then
    ssh_system_log "INFO" "Attempting to load configuration from ${local_config_file}" "${log_file}"
    # shellcheck source=./$local_config_file
    source "${local_config_file}"
    ssh_system_log "INFO" "Loaded configuration from ${local_config_file}" "${log_file}"
  else
    ssh_system_log "ERROR" "Configuration file not found. Using default settings." "${error_log_file}"
    generate_default_config "${local_config_file}" "${log_file}" "${error_log_file}" "${default_alert_email}" "${default_alert_threshold}" "${default_mail_subject}"
  fi
}

# Generate the default configuration if it doesn't exist
generate_default_config() {
  local local_config_file="$1"
  local log_file="$2"
  local error_log_file="$3"
  local default_alert_email="$4"
  local default_alert_threshold="$5"
  local default_mail_subject="$6"

  if [[ ! -f ${local_config_file}   ]]; then
    cat <<- EOF > "${local_config_file}"
      log_file="${log_file}"
      error_log_file="${error_log_file}"
      alert_email="${default_alert_email}"
      alert_threshold="${default_alert_threshold}"
      mail_subject="${default_mail_subject}"
EOF
    ssh_system_log "INFO" "Default configuration file generated at ${local_config_file}" "${log_file}"
  else
    ssh_system_log "INFO" "Configuration file already exists. Skipping generation." "${log_file}"
  fi
}

# Create the systemd service file
create_daemon_service() {
  local log_file="$1"
  local error_log_file="$2"
  local script_dir="$3"
  local service_file="$4"
  local description="$5"
  local service_name="$6"

  {
    cat <<- EOF
      [Unit]
      Description=${description}

      [Service]
      ExecStart=${script_dir}/$(dirname "$0")/standalones/sshd/setup_ssh_intrusion_detection.sh
      Restart=always

      [Install]
      WantedBy=multi-user.target
EOF
  } > "${service_file}" || {
    ssh_system_log "ERROR" "Unable to create service file." "${error_log_file}"
    return 1
  }

  ssh_system_log "INFO" "Created service file at ${service_file}" "${log_file}"

  enable_service "${service_name}"
  start_service "${service_name}"

}

# Manage the SSH Monitor daemon
manage_daemon() {
  local log_file="$1"
  local error_log_file="$2"
  local script_dir="$3"
  local service_file="$4"
  local service_name="$5"
  local description="$6"

  case "$7" in
    install)
      create_daemon_service "${log_file}" "${error_log_file}" "${script_dir}" "${service_file}" "${description}" "${service_name}" || return 1
      ;;
    status)
      systemctl status "${service_name}" || ssh_system_log "ERROR" "Failed to get status of the ${service_name} daemon." "${error_log_file}"
      ;;
    stop)
      systemctl stop "${service_name}" || ssh_system_log "ERROR" "Failed to stop the ${service_name} daemon." "${error_log_file}"
      ;;
    disable)
      systemctl disable "${service_name}" && systemctl stop "${service_name}"
      ssh_system_log "INFO" "${service_name} daemon disabled and stopped." "${log_file}"
      ;;
    *)
      ssh_system_log "ERROR" "Invalid command. Usage: $0 [install|status|stop|disable]" "${error_log_file}"
      exit 1
      ;;
  esac
}

# Check if the session count exceeds the alert threshold and send an alert if necessary
handle_ssh_threshold_exceeds() {
  local session_count="$1"
  local session_details="$2"
  if ((session_count >= alert_threshold)); then
    local message="Alert: High number of SSH logins detected. Count: ${session_count}\n\nSession Details:\n${session_details}"
    send_email_with_throttle "${mail_subject}" "${message}" "${alert_email}" "${last_email_sent_file}"
    ssh_system_log "INFO" "Checked SSH session count (${session_count}) against threshold." "${log_file}"
  else
    ssh_system_log "INFO" "SSH session count (${session_count}) is below the threshold." "${log_file}"
  fi
}

# Manage SSH sessions
handle_ssh_sessions() {
  # Get the current time in the format: YYYY-MM-DD HH:MM
  local now
  now=$(date '+%Y-%m-%d %H:%M')

  # Calculate the time 20 seconds ago in the same format
  local twenty_seconds_ago
  twenty_seconds_ago=$(date '+%Y-%m-%d %H:%M' -d "20 seconds ago")

  # Use the corrected format for 'last' command's time range filtering
  local ssh_sessions
  ssh_sessions=$(last -s "${twenty_seconds_ago}" -t "${now}" | grep 'pts/' | sort | uniq -c) || {
    ssh_system_log "ERROR" "Unable to fetch SSH session data using 'last' command." "${error_log_file}"
    return 1
  }

  echo "${now}" > "${last_check_file}" || {
    ssh_system_log "ERROR" "Unable to update last check file." "${error_log_file}"
    return 1
  }

  if [[ -n ${ssh_sessions} ]]; then
    log_session_data "${ssh_sessions}"
    ssh_system_log "INFO" "Logged SSH sessions data." "${log_file}"
    local session_count
    session_count=$(echo "${ssh_sessions}" | wc -l)
    handle_ssh_threshold_exceeds "${session_count}" "${ssh_sessions}"
  else
    ssh_system_log "INFO" "No SSH sessions found in this interval." "${log_file}"
  fi
}

# Log session data to the ssh_system_log file
log_session_data() {
  local line
  while read -r line; do
    if [[ ! -f ${log_file}   ]]; then
      touch "${log_file}" || {
        ssh_system_log "ERROR" "Unable to create ssh_system_log file." "${error_log_file}"
        return 1
      }
      ssh_system_log "INFO" "Created ssh_system_log file at ${log_file}" "${log_file}"
    fi

    {
      echo "[$(date '+%a %b %d %H:%M')] New SSH sessions detected:"
      echo "${line}"
    } >> "${log_file}" || {
      ssh_system_log "ERROR" "Unable to write to ssh_system_log file." "${error_log_file}"
      return 1
    }
  done <<< "$1"
}

# Rotate ssh_system_log files if they exceed the given size
rotate_logs() {
  local log_file_to_rotate="$1"
  local max_size_kb="$2"
  if [[ -f ${log_file_to_rotate}   ]]; then
    local file_size_kb
    file_size_kb=$(du -k "${log_file_to_rotate}" | cut -f1)
    if ((file_size_kb >= max_size_kb)); then
      local backup_name
      backup_name="${log_file_to_rotate}_$(date '+%Y%m%d%H%M%S')"
      mv "${log_file_to_rotate}" "${backup_name}"
      touch "${log_file_to_rotate}"
      ssh_system_log "INFO" "Rotated ssh_system_log file: ${backup_name}"
    fi
  fi
}

# Handle file checks
handle_file_checks() {
  local files_to_check
  files_to_check=(
    "${log_file}"
    "${error_log_file}"
    "${last_check_file}"
    "${last_email_sent_file}"
  )

  local file
  for file in "${files_to_check[@]}"; do
    ssh_system_log "INFO" "Checking file: ${file}" "${log_file}"
    check_and_create_file "${file}" "${log_file}"
    verify_file_is_writable "${file}" "${log_file}"
  done
}

# Main function
main() {
  check_root
  echo "Initializing SSHD IDS..."

  initialize_variables
  handle_file_checks
  load_config "${local_config_file}" "${log_file}" "${error_log_file}" "${default_alert_email}" "${default_alert_threshold}" "${default_mail_subject}"

  # Check command line arguments for daemon management
  if [[ $1 =~ ^(install|status|stop|disable)$ ]]; then
    manage_daemon "${log_file}" "${error_log_file}" "${script_dir}" "${service_file}" "${service_name}" "${service_description}" "$1"
  else
    local cycle_duration=20
    while true; do
      rotate_logs "${log_file}" 1024
      rotate_logs "${error_log_file}" 1024

      local start_time
      start_time=$(date +%s)

      handle_ssh_sessions || ssh_system_log "ERROR" "Error occurred during SSH session logging." "${error_log_file}"

      local end_time elapsed sleep_duration
      end_time=$(date +%s)
      elapsed=$((end_time - start_time))
      sleep_duration=$((cycle_duration - elapsed))

      if ((sleep_duration > 0)); then
        sleep "${sleep_duration}"
      else
        ssh_system_log "INFO" "Warning: Script execution time exceeded the cycle duration." "${log_file}"
      fi
    done
  fi
}

# Execute the main function with command line arguments
main "$@"
