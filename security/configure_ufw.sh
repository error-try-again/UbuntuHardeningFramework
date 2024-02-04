#!/bin/bash

  # Configure UFW firewall
function configure_ufw() {
  # Install ufw if it's not already installed
  if ! run_remote_command "sudo -S apt-get update && sudo -S apt-get install ufw -y"; then
    echo "Error: Failed to install ufw"
    prompt_user_for_actions
  fi

  # Enable ufw and deny all incoming traffic by default
  if ! run_remote_command "sudo -S ufw enable && sudo -S ufw default deny incoming"; then
    echo "Error: Failed to configure ufw"
    prompt_user_for_actions
  fi

  # Allow SSH traffic
  if ! run_remote_command "sudo -S ufw allow ssh"; then
    echo "Error: Failed to allow SSH traffic in ufw"
    prompt_user_for_actions
  fi

  echo "+++++++++++++++++++++++++"
  echo "Firewall is now configured to only allow SSH traffic."
  echo "+++++++++++++++++++++++++"
  prompt_user_for_actions
}