#!/bin/bash

#######################################
# description
# Globals:
#   remote_host
#   remote_port
#   remote_user
# Arguments:
#  None
#######################################
function copy_public_key_to_remote_server() {
  echo "Copying fingerprint to known hosts..."
  if ! ssh-keyscan -p "${remote_port}" "${remote_host}" >>~/.ssh/known_hosts; then
    echo "Error: Failed to add remote host to known_hosts"
    prompt_user_for_actions
  fi

  echo "Installing public key on remote..."
  if ! ssh-copy-id -p "${remote_port}" "${remote_user}@${remote_host}"; then
    echo "Error: Failed to copy public key to remote server"
    prompt_user_for_actions
  else
    echo "+++++++++++++++++++++++++"
    echo "Public key copied successfully!"
    echo "+++++++++++++++++++++++++"
    prompt_user_for_actions
  fi
}
