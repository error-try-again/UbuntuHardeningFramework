#!/bin/bash

# Change admin password
function change_admin_password() {
  echo "Changing admin password..."
  if ! run_remote_command "sudo -S passwd admin"; then
    echo "Error: Failed to change admin password"
    echo "Retry or skip?"
    local yn
    select yn in "Retry" "Skip"; do
      case ${yn} in
        Retry)
          if run_remote_command "sudo -S passwd root"; then
            echo "+++++++++++++++++++++++++"
            echo "Admin password changed successfully!"
            echo "+++++++++++++++++++++++++"
            break
          else
            echo "Failed to change admin password"
          fi
          ;;
        Skip)
          break
          ;;
        *)
          echo "Please select 1 or 2"
          ;;
      esac
    done
  fi
}
