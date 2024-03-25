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
}

# Append or update a line in a file with a key value pair
write_key() {
  local key="$1"
  local value="$2"
  local config_file="$3"
  echo "${key} ${value}" >> "${config_file}"
}

# Updates the cron job for a script
update_cron_job() {
  if [[ -z "$1" ]] || [[ -z "$2" ]]; then
    log "Usage: update_cron_job <script_path> <log_file_path>"
    return 1
  fi

  local script="$1"
  local log_file="$2"
  local cron_entry="0 0 * * * ${script} >${log_file} 2>&1"

  # Attempt to read existing cron jobs, suppressing errors about no existing crontab
  local current_cron_jobs
  if ! current_cron_jobs=$(crontab -l 2>/dev/null); then
    log "No existing crontab for user. Creating new crontab..."
  fi

  # Check if the cron job already exists and is up-to-date
  if echo "${current_cron_jobs}" | grep -Fxq -- "${cron_entry}"; then
    log "Cron job already up to date."
    return 0
  else
    log "Cron job for script not found or not up-to-date. Adding new job..."
  fi

  # Add the cron job to the crontab
  if (echo "${current_cron_jobs}"; echo "${cron_entry}") | crontab -; then
    log "Cron job added successfully."
  else
    log "Failed to add cron job."
  fi

}

# Configures automatic updates
configure_auto_updates() {
  # Configure automatic updates
  local config_file="/etc/apt/apt.conf.d/50unattended-upgrades"
  local recipients="${1}"

  # Define the lines to insert
  declare -A updates=(
          ["Unattended-Upgrade::DevRelease"]='"auto";'
          ["Unattended-Upgrade::MinimalSteps"]='"true";'
          ["Unattended-Upgrade::Mail"]="\"${recipients}\";"
          ["Unattended-Upgrade::MailReport"]='"always";'
          ["Unattended-Upgrade::Remove-Unused-Kernel-Packages"]='"false";'
          ["Unattended-Upgrade::Automatic-Reboot-WithUsers"]='"true";'
          ["Unattended-Upgrade::Automatic-Reboot-Time"]='"00:00";'
          ["Unattended-Upgrade::Automatic-Reboot"]='"true";'
          ["Acquire::http::Dl-Limit"]='"10000";'
          ["Unattended-Upgrade::SyslogEnable"]='"true";'
          ["Unattended-Upgrade::SyslogFacility"]='"daemon";'
          ["Unattended-Upgrade::Verbose"]='"true";'
          ["Unattended-Upgrade::Debug"]='"true";'
          ["Unattended-Upgrade::AutoFixInterruptedDpkg"]='"true";'
  )

  # Clear the contents of the file
  echo "" > "${config_file}"

  # Update each entry
  local key
  for key in "${!updates[@]}"; do
    echo "Updating ${key}..."
    write_key "${key}" "${updates[${key}]}" "${config_file}"
  done

    # Add an Unattended-Upgrade::Allowed-Origins section
    cat << EOF | sudo tee -a "${config_file}" > /dev/null
Unattended-Upgrade::Allowed-Origins {
        "\${distro_id}:\${distro_codename}";
        "\${distro_id}:\${distro_codename}-security";
        "\${distro_id}ESMApps:\${distro_codename}-apps-security";
        "\${distro_id}ESM:\${distro_codename}-infra-security";
        "\${distro_id}:\${distro_codename}-updates";
};
EOF

  update_cron_job "/usr/bin/unattended-upgrade -d" "/var/log/unattended-upgrades.log"
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

# Main
main() {
  check_root

  echo "Initializing unattended-upgrades..."
  local recipients="${1:-root@$(hostname -f)}" # Default recipient email if not provided

  install_apt_packages "debconf-utils" "unattended-upgrades"
  configure_auto_updates "${recipients}"
}

main "$@"