#!/usr/bin/env bash

set -euo pipefail

# Checks if the script is being run as root
check_root() {
  if [[ ${EUID} -ne 0   ]]; then
    echo "Please run as root"
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

# Configures automatic updates
configure_auto_updates() {
  # Configure automatic updates
  local config_file="/etc/apt/apt.conf.d/50unattended-upgrades"

  # Define the lines to insert
  declare -A updates=(
          ["Unattended-Upgrade::DevRelease"]='"auto";'
          ["Unattended-Upgrade::MinimalSteps"]='"true";'
          ["Unattended-Upgrade::Mail"]='"example.eg@example.com";'
          ["Unattended-Upgrade::MailReport"]='"always";'
          ["Unattended-Upgrade::Remove-Unused-Kernel-Packages"]='"false";'
          ["Unattended-Upgrade::Automatic-Reboot-WithUsers"]='"true";'
          ["Unattended-Upgrade::Automatic-Reboot-Time"]='"00:00";'
          ["Acquire::http::Dl-Limit"]='"100";'
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

# Main
main() {
  check_root
  echo "Initializing unattended-upgrades..."
  install_apt_packages "debconf-utils" "unattended-upgrades"
  configure_auto_updates
}

main "$@"
