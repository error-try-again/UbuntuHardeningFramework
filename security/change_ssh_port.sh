#!/bin/bash

 # Change the default SSH port
function change_ssh_port() {
  local default_port=22
  local new_port=0

  echo "Changing default SSH port..."

  local choice
  # Prompt the user to choose a new port number
  read -r -p "Would you like to change the current SSH port? (y/n): " choice

  if [[ ${choice} =~ ^[yY]$ ]]; then
    # Prompt the user to enter a custom port number
    read -r -p "Enter the new SSH port number: " new_port

    # Validate that the new port number is valid
    if ! [[ ${new_port} =~ ^[0-9]+$ ]]; then
      echo "Invalid port number. Please enter a valid integer port number."
       prompt_user_for_actions
    fi

    # Update the default port number in the script
    default_port=${new_port}
  else
     echo "Skipping..."
    prompt_user_for_actions
  fi

  # Check if the sshd_config file exists and has the correct permissions
  if ! run_remote_command "sudo -S test -f ${sshd_config} && sudo -S test -w ${sshd_config}"; then
    echo "Error: ${sshd_config} does not exist or is not writable."
    prompt_user_for_actions
    return 1
  fi

  # Try to change the SSH port
  if run_remote_command "sudo -S sed -i 's/#Port ${default_port}/Port ${new_port}/g' ${sshd_config}"; then
    echo "SSH port changed successfully!"
    prompt_user_for_actions
  else
    echo "Failed to change SSH port."
    prompt_user_for_actions
  fi
}
