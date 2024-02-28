#!/usr/bin/env bash

set -euo pipefail

# Create an administrative user
create_administrative_user() {
  local user=${1}

  echo "Creating administrative user '${user}'..."
  if sudo -S adduser "${user}" && sudo -S usermod -aG sudo "${user}"; then
    echo "${user} has been added to the sudo group."
  else
    echo "Failed to create administrative user '${user}'. Exiting."
    exit 1
  fi
}

# Initialize SSH key-based authentication
setup_ssh_key_authentication() {
  local user=${1}

  local user_home
  user_home=$(getent passwd "${user}")
  user_home=$(echo "${user_home}" | cut -d: -f6)

  echo "Setting up SSH key authentication for '${user}'..."
  sudo -S mkdir -p "${user_home}/.ssh"
  sudo -S touch "${user_home}/.ssh/authorized_keys"
  sudo -S chmod 700 "${user_home}/.ssh"
  sudo -S chmod 600 "${user_home}/.ssh/authorized_keys"
  sudo -S chown -R "${user}:${user}" "${user_home}/.ssh"

  echo "SSH key authentication setup for ${user}."
}

# Main function
main() {
  if [[ $# -ne 1 ]]; then
    show_help
    exit 1
  fi

  local user=${1}

  # Create an administrative user
  create_administrative_user "${user}"

  # Setup SSH key-based authentication for the user
  setup_ssh_key_authentication "${user}"
}

main "${@}"

# To set up SSH access while root access is still enabled perform the following:
# ssh -v -i ~/.ssh/ssd-nodes root@5.5.5.5 "cat >> /home/void/.ssh/authorized_keys" < "/home/void/.ssh/ssd-nodes.pub" 2>/dev/null