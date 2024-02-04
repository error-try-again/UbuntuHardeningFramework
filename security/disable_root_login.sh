#!/bin/bash

  # Disable root login
function disable_root_login() {
  echo "Disabling root login..."
  if ssh -i "${ssh_local_pem}" "${remote_user}@${remote_host}" "sudo -S sed -i '/^#.*PermitRootLogin/ s/^#//' ${sshd_config} && \
    sudo -S sed -i 's/PermitRootLogin .*/PermitRootLogin no/g' ${sshd_config} && \
    sudo -S systemctl restart ssh"; then
    echo "+++++++++++++++++++++++++"
    echo "Root login disabled successfully!"
    echo "+++++++++++++++++++++++++"
    return 1
  else
    echo "Failed to disable root login. Skipping or exiting..."
    return 1
  fi
}
