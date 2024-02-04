#!/bin/bash

  # generate key pair for new user
  function generate_ssh_keypair() {
    echo "Generating (local) SSH key pair for new remote user..."
    if ! ssh-keygen -t ed25519 -f ~/.ssh/"${new_user}" -C "${new_user}@localhost" -q -N ""; then
      echo "Error: Failed to generate SSH key pair for new user"
      prompt_user_for_actions
  else
       echo "+++++++++++++++++++++++++"
    echo "SSH key pair generated successfully!"
    echo "+++++++++++++++++++++++++"
  fi
}
