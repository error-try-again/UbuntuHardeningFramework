#!/bin/bash

 # Create a new admin user with sudo privileges
function create_admin() {
  echo "Creating new admin user..."
  run_remote_command "sudo -S adduser ${new_user} && \
  sudo -S usermod -aG sudo ${new_user}"
  prompt_user_for_actions
}
