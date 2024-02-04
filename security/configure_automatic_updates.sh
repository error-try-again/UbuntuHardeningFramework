#!/bin/bash

# Configure automatic updates
function configure_automatic_updates() {
  echo "Configuring automatic updates..."

  if ! ssh -i "${ssh_local_pem}" "${remote_user}@${remote_host}" 'sudo apt-get update && sudo -S apt-get install unattended-upgrades -y';
   then
    echo "Error: Failed to install unattended-upgrades"
  fi

  # Enable automatic updates
  if ! ssh -i "${ssh_local_pem}" "${remote_user}@${remote_host}" 'sudo dpkg-reconfigure --priority=low unattended-upgrades'; then
    echo "Error: Failed to configure automatic updates"
  else
    echo "Automatic updates configured successfully!"
    echo "+++++++++++++++++++++++++"
  fi
}
