#!/usr/bin/env bash

#######################################
# Checks if the script is being run as root (used for apt)
# Globals:
#   EUID
# Arguments:
#  None
#######################################
check_root() {
  if [[ ${EUID} -ne 0   ]]; then
    echo "Please run as root"
    exit 1
  fi
}

#######################################
# Installs apt packages
# Arguments:
#  None
#######################################
install_apt_packages() {
  apt install rkhunter debconf-utils unattended-upgrades -y
}

#######################################
# Configures automatic updates
# Globals:
#   config_file
# Arguments:
#  None
#######################################
configure_auto_updates() {
  # Configure automatic updates
  config_file="/etc/apt/apt.conf.d/50unattended-upgrades"

  # Define the lines to insert
  declare -A updates=(
        ["Unattended-Upgrade::DevRelease"]='"auto";'
        ["Unattended-Upgrade::MinimalSteps"]='"true";'
        ["Unattended-Upgrade::Mail"]='"yane.neurogames@gmail.com";'
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

  echo "Backing up ${config_file}..."

  # Clear the contents of the file
  echo "" > "${config_file}"

  # Update each entry
  local key
  for key in "${!updates[@]}"; do
    echo "Updating ${key}..."
    write_key "${key}" "${updates[${key}]}"
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

#######################################
# Append or update a line in a file with a key value pair
# Globals:
#   config_file
# Arguments:
#   1
#   2
#######################################
write_key() {
    local key="$1"
    local value="$2"
    echo "${key} ${value}" >> "${config_file}"
}

#######################################
# Updates the cron job for a script
# Arguments:
#   1
#######################################
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

#######################################
# Main
# Arguments:
#  None
#######################################
main() {
  check_root

  # Automatic updates
  install_apt_packages
  configure_auto_updates
}

main "$@"
