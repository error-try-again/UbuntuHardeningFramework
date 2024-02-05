#!/usr/bin/env bash

# Copy the lynis installer script to the relevant directory
copy_installer() {
  local installer_location="$1"

  cp ./standalones/lynis/install_lynis.sh "${installer_location}"

  chmod 700 "${installer_location}"

  # Source the newly created installer script
  # shellcheck source=./${installer_location}
  . "${installer_location}"
}

# Main function to control script flow
main_lynis_setup() {
  check_root
  echo "Initializing Lynis..."
  local lynis_script_path="/usr/local/bin/lynis_installer.sh"
  # Dynamically generate the installer
  copy_installer "${lynis_script_path}"
  # Update the cron job
  update_cron_job "${lynis_script_path}" "/var/log/lynis_cron.log"
}
