#!/bin/bash

 # Install and configure SELinux
function install_selinux() {
  # Check if SELinux is already installed
  if run_remote_command "sudo -S selinuxenabled"; then
    echo "SELinux is already installed and enabled"
    prompt_user_for_actions
  fi

  echo "Installing SELinux..."
  if ! run_remote_command "sudo -S apt-get update && \
    sudo -S apt-get install policycoreutils selinux-utils selinux-basics -y"; then
    echo "Error: Failed to install SELinux"
    prompt_user_for_actions
  else
    echo "+++++++++++++++++++++++++"
    echo "SELinux installed successfully!"
    echo "+++++++++++++++++++++++++"
  fi

  # Activate SELinux
  echo "Activating SELinux..."
  if ! run_remote_command "sudo -S selinux-activate"; then
    echo "Error: Failed to activate SELinux"
    prompt_user_for_actions
  else
    echo "+++++++++++++++++++++++++"
    echo "SELinux activated successfully!"
    echo "+++++++++++++++++++++++++"
  fi

  # Reboot system
  echo "Rebooting system..."
  run_remote_command "sudo -S reboot"
}