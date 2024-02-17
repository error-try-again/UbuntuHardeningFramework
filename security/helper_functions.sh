#!/usr/bin/env bash

# helper function to run a command on the remote server
function run_remote_command() {
    ssh -i "${ssh_local_pem}" "${remote_user}@${remote_host}"
}

 # helper function to skip or exit the script
function retry_or_exit() {
    echo "Go back or exit?"
    local yn
    select yn in "Back" "Exit"; do
        case ${yn} in
            Back) prompt_user_for_actions ;;
            Exit) exit ;;
        *)  echo "Please answer 1 or 2." ;;
    esac
  done
}
