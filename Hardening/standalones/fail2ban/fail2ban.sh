#!/usr/bin/env bash

# Check if the script is being run as root
check_root() {
  if [[ ${EUID} -ne 0   ]]; then
    log "This script must be run as root."
    exit 1
  fi
}

# Initialize variables
initialize_variables() {
  custom_jail="/etc/fail2ban/jail.local"
  log_file="/var/log/fail2ban-setup.log"
  local ip_list="167.179.173.46/32"

  export custom_jail ip_list log_file
}

# Log messages to a log file
log() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - ${message}" >> "${log_file}"
}

# Install Fail2ban via apt
install_apt_packages() {
  log "Updating package list and installing Fail2ban..."
  {
    apt update -y && apt install fail2ban -y
  } || {
    log "Fail2ban installation failed."
    exit 1
  }
  log "Fail2ban installation completed."
}

# View the status of Fail2ban service
view_fail2ban_status() {
  log "Checking Fail2ban service status..."
  systemctl status fail2ban --no-pager
}

# Start Fail2ban service
start_fail2ban() {
  log "Starting Fail2ban service..."
  systemctl start fail2ban --no-pager || {
      log "Fail2ban service failed to start."
      exit 1
  }
  log "Fail2ban service started."
}

# Enable Fail2ban service to start on boot
enable_fail2ban() {
  log "Enabling Fail2ban service to start on boot..."
  systemctl enable fail2ban --no-pager || {
      log "Fail2ban service failed to enable to start on boot."
      exit 1
  }
  log "Fail2ban service enabled to start on boot."
}

# Restart Fail2ban service
restart_fail2ban() {
  log "Restarting Fail2ban service..."
  systemctl restart fail2ban --no-pager || {
      log "Fail2ban service failed to restart."
      exit 1
  }
  log "Fail2ban service restarted."
}

# View the first 20 lines of Fail2ban configuration file
view_fail2ban_configuration() {
    log "Viewing the first 20 lines of Fail2ban configuration..."
    head -n 20 /etc/fail2ban/jail.conf
}

# Backup the existing Fail2ban jail configuration
backup_jail_configuration() {
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
  }   && {
        log "Backup of Fail2ban jail configuration created."
  }
}

# Create a custom Fail2ban jail configuration for SSH protection
create_jail_configuration() {
  local custom_jail="${1}"
  local ip_list="${2:-127.0.0.1}" # Default IP list to localhost if not provided

  # Check if parameters are provided
  if [[ -z ${custom_jail}   ]]; then
      echo "Error: No file path provided for the jail configuration."
      return 1
  fi

    # Create a custom jail configuration for SSH if it doesn't exist
    cat <<- EOF > "${custom_jail}"
        [sshd]
        enabled = true
        port = ssh
        filter = sshd
        logpath = /var/log/auth.log
        maxretry = 3
        findtime = 600
        bantime = 3600
        ignoreip = ${ip_list}
        destemail = yane.neurogames@gmail.com
        sender = yane.neurogames@gmail.com
        sendername = Fail2Ban
        mta = sendmail
        action = %(action_mwl)s
EOF
}

# Configure a custom Fail2ban jail for SSH protection
configure_custom_jail() {
  log "Configuring a custom Fail2ban jail for SSH protection..."

  create_jail_configuration "${custom_jail}"

  # Restart Fail2ban service to apply the new configuration
  restart_fail2ban
}

# Main function
main() {
  check_root
  initialize_variables

  # Ensure that a file exists
  ensure_file_exists() {
    local file="$1"
    if [[ ! -f ${file}   ]]; then
      touch "${file}" || {
        log "ERROR" "Unable to create file: ${file}" "${error_log_file}"
        exit 1
      }
    fi
  }

  # Ensure that a file is writeable
  ensure_file_is_writeable() {
    local file="$1"
    if [[ ! -w ${file}   ]]; then
      log "ERROR" "File is not writable: ${file}" "${error_log_file}"
      exit 1
    fi
  }

  local files_to_check
  files_to_check=(
    "${log_file}"
    "${custom_jail}"
  )

  local file
  for file in "${files_to_check[@]}"; do
    log "Checking if the file exists and is writeable: ${file}"
    ensure_file_exists "${file}"
    ensure_file_is_writeable "${file}"
  done

  install_apt_packages
  view_fail2ban_status
  start_fail2ban
  enable_fail2ban
  view_fail2ban_configuration
  backup_jail_configuration
  configure_custom_jail
}

# Call the main function and log the output
main "$@"
