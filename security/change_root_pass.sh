#!/bin/bash

 # Change root password
function change_root_password() {
  echo "Changing root password..."
  run_remote_command "sudo -S passwd root"
  prompt_user_for_actions
}