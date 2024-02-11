#!/bin/bash

 # Check and set SSH option
function check_and_set_ssh_option() {
  local option=$1
  local value=$2
  if run_remote_command "grep -E '^${option}\s+${value}' ${sshd_config}"; then
    echo "SSH option ${option} is already set to ${value}."
  else
    if ! run_remote_command "sudo -S sed -i 's/^#${option}\s\+.*$/${option} ${value}/g' ${sshd_config} && \
                              sudo -S systemctl restart ssh"; then
      echo "Error: Failed to set SSH option ${option} to ${value}"
      prompt_user_for_actions
    else
      if run_remote_command "grep -E '^${option}\s+${value}' ${sshd_config}"; then
        echo "SSH option ${option} is now set to ${value}."
      else
        echo "Error: Failed to set SSH option ${option} to ${value}"
        prompt_user_for_actions
      fi
    fi
  fi
}
