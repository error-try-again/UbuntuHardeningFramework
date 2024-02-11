#!/usr/bin/env bash

# Append or update a line in a file with a key value pair
write_key() {
  local key="$1"
  local value="$2"
  local config_file="$3"
  echo "${key} ${value}" >> "${config_file}"
}

# Configures automatic updates
configure_auto_updates() {
  # Configure automatic updates
  local config_file="/etc/apt/apt.conf.d/50unattended-upgrades"

  # Define the lines to insert
  declare -A updates=(
          ["Unattended-Upgrade::DevRelease"]='"auto";'
          ["Unattended-Upgrade::MinimalSteps"]='"true";'
          ["Unattended-Upgrade::Mail"]='"yane.neurogames@gmail.com,yane.karov@gmail.com";'
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

# Main
main_auto_upgrades_setup() {
  check_root
  echo "Initializing unattended-upgrades..."
  install_apt_packages "debconf-utils" "unattended-upgrades"
  configure_auto_updates
}
