#!/bin/bash

#######################################
# description
# Arguments:
#  None
#######################################
function prompt_user_for_actions() {
    local options=(
       "Generate SSH key pair for new user"
    "Copy public key to remote server"
    "Create new admin user"
    "Configure SSH key-based authentication"
    "Change SSH port"
    "Change root password"
    "Change admin password"
    "Install SELinux"
    "Setup MFA"
    "Configure fail2ban"
    "Disable root login"
    "Configure UFW"
    "Configure automatic updates"
    "Exit"
  )
  local actions=()

  echo "Select the actions you would like to perform:"
  local i
  for i in "${!options[@]}"; do
    echo "$((i + 1)). ${options[${i}]}"
  done

  while true; do
    read -r -p "Enter the number(s) of the actions you want to perform (separated by space): " -a actions
    local invalid=0
    local action
    for action in "${actions[@]}"; do
      if [[ ! ${action} =~ ^[0-9]+$ ]] || ((action < 1 || action > ${#options[@]})); then
        invalid=1
        break
      fi
    done
    if [[ ${invalid} -eq 0 ]]; then
      break
    else
      echo "Invalid input. Please enter the number(s) of the actions you want to perform."
    fi
  done

  for action in "${actions[@]}"; do
    case ${action} in
      1) generate_ssh_keypair ;;
      2) copy_public_key_to_remote_server ;;
      3) create_admin ;;
      4) configure_ssh_key_auth ;;
      5) change_ssh_port ;;
      6) change_root_password ;;
      7) change_admin_password ;;
      8) install_selinux ;;
      9) setup_mfa ;;
      10) configure_fail2ban ;;
      11) disable_root_login ;;
      12) configure_ufw ;;
      13) configure_automatic_updates ;;
      14) exit ;;
      *) echo "Invalid choice. Skipping action." ;;
    esac
  done
}
