#!/usr/bin/env bash

set -euo pipefail

# Log messages to a log file
log() {
  local message="$1"
  local date
  date=$(date +'%Y-%m-%d %H:%M:%S')
  echo "${date} - ${message}"
}

# Checks if the script is being run as root
check_root() {
  if [[ ${EUID} -ne 0   ]]; then
    echo "Please run as root"
    exit 1
  fi
}

# Enable and start a service
enable_service() {
  local service_name="$1"
  systemctl enable "${service_name}" --no-pager
}

# Restart a service
restart_service() {
  local service_name="$1"
  systemctl restart "${service_name}" --no-pager
}

# Start a service
start_service() {
  local service_name="$1"
  systemctl start "${service_name}" --no-pager
}

# Retrieve service status
status_service() {
  local service_name="$1"
  systemctl status "${service_name}" --no-pager
}

# View the first 40 lines of Fail2ban configuration file
view_fail2ban_config() {
    log "Viewing the first 40 lines of Fail2ban configuration..."
    head -n 40 /etc/fail2ban/jail.conf
}

# Backup the existing Fail2ban jail configuration
backup_jail_config() {
  local backup_dir="/etc/fail2ban/backup"
  local current_config="/etc/fail2ban/jail.local"
  local timestamp
  timestamp=$(date +"%Y%m%d%H%M%S")

  log "Creating a backup of Fail2ban jail configuration..."

  # Create the backup directory if it doesn't exist
  mkdir -p "${backup_dir}"

  # Copy the current jail configuration to the backup directory
  cp "${current_config}" "${backup_dir}/jail.local_${timestamp}.bak" || {
    log "Failed to create a backup of Fail2ban jail configuration."
    exit 1
  } && {
    log "Backup of Fail2ban jail configuration created."
  }
}

# Create a custom Fail2ban jail configuration for SSH protection
create_jail_config() {
  local custom_jail="${1}"
  local ip_list="${2:-127.0.0.1}" # Default IP list to localhost if not provided

  # Check if parameters are provided
  if [[ -z ${custom_jail} ]]; then
    echo "Error: No file path provided for the jail configuration."
    return 1
  fi

    # Aggressive jail configuration for SSH
    cat <<- EOF > "${custom_jail}"
        [sshd]
        enabled = true
        port = ssh
        filter = sshd
        logpath = /var/log/auth.log
        maxretry = 3
        findtime = 300
        bantime = 86400
        ignoreip = ${ip_list}
        destemail = example.eg@example.com
        sender = example1.eg@example.com
        sendername = Fail2Ban
        mta = sendmail
        action = %(action_mwl)s
        bantime.increment = true
EOF
}

# Create a generic file if it doesn't exist
create_file_if_not_exists() {
  local file="$1"
  local error_log_file="$2"
  if [[ ! -f ${file} ]]; then
    touch "${file}" || {
      system_log "ERROR" "Unable to create file: ${file}" "${error_log_file}"
      exit 1
    }
  fi
}

# Ensure a file is writable
ensure_file_is_writable() {
  local file="$1"
  local error_log_file="$2"
  if [[ ! -w ${file} ]]; then
    system_log "ERROR" "File is not writable: ${file}" "${error_log_file}"
    exit 1
  fi
}

# Installs a list of apt packages
install_apt_packages() {
  local package_list=("${@}") # Capture all arguments as an array of packages
  apt update -y || { log "Failed to update package lists..."; exit 1; }
  local package
  for package in "${package_list[@]}"; do
    local dpkg_list
    dpkg_list=$(dpkg -l | grep -w "${package}")
    if [[ -n "${dpkg_list}" ]]; then
      log "${package} is already installed."
    else
      # Sleep to avoid "E: Could not get lock /var/lib/dpkg/lock-frontend" error when running in parallel with other apt commands
      sleep 1
      if apt install -y "${package}"; then
        log "Successfully installed ${package}."
      else
        log "Failed to install ${package}..."
        exit 1
      fi
    fi
  done
}

# Main function
main() {
  check_root
  echo "Initializing Fail2Ban..."

  local custom_jail="/etc/fail2ban/jail.local"
  local fail2ban_log_file="/var/log/fail2ban-setup.log"
  # TODO: Replace with the actual IP list of the server
  local ip_list="5.5.5.5/32"

  install_apt_packages "fail2ban"

  create_file_if_not_exists "${fail2ban_log_file}" "${fail2ban_log_file}"
  create_file_if_not_exists "${custom_jail}" "${fail2ban_log_file}"

  ensure_file_is_writable "${fail2ban_log_file}" "${fail2ban_log_file}"
  ensure_file_is_writable "${custom_jail}" "${fail2ban_log_file}"

  status_service "fail2ban"
  start_service "fail2ban"
  enable_service "fail2ban"

  view_fail2ban_config
  backup_jail_config

  # Create a custom Fail2ban jail configuration for SSH protection
  create_jail_config "${custom_jail}" "${ip_list}"

  # Restart Fail2ban service to apply the new configuration
  restart_service "fail2ban"
}

main "$@"