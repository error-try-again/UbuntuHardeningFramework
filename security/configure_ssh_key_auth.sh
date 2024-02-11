#!/bin/bash

function configure_ssh_key_auth() {
  # Configure SSH to use key-based authentication
  echo "Creating .ssh directory on remote server if it doesn't exist..."
  if ! run_remote_command "mkdir -p /home/${new_user}/.ssh && chmod 700 /home/${new_user}/.ssh"; then
    echo "Error: Failed to create .ssh directory"
    prompt_user_for_actions
  fi

  echo "Configuring authorized_keys..."
  if ! cat ~/.ssh/"${new_user}".pub | run_remote_command "[ -f /home/${new_user}/.ssh/authorized_keys ] && \
    cat >> /home/${new_user}/.ssh/authorized_keys || \
    (mkdir -p /home/${new_user}/.ssh && \
    touch /home/${new_user}/.ssh/authorized_keys && \
    chmod 600 /home/${new_user}/.ssh/authorized_keys && \
    cat >> /home/${new_user}/.ssh/authorized_keys) && \
    chmod 600 /home/${new_user}/.ssh/authorized_keys && \
    chown -R ${new_user}:${new_user} /home/${new_user}/.ssh"; then
    echo "Error: Failed to configure authorized_keys"
    prompt_user_for_actions
  fi

  echo "Disabling password authentication and enabling public key authentication..."
  if ! run_remote_command "sudo -S sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' ${sshd_config} && \
			sudo -S sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' ${sshd_config} && \
			sudo -S systemctl restart ssh"; then
    echo "Error: Failed to configure SSH on remote server"
    prompt_user_for_actions
  else
    echo "+++++++++++++++++++++++++"
    echo "SSH configured successfully!"
    echo "+++++++++++++++++++++++++"
    prompt_user_for_actions
  fi

}
