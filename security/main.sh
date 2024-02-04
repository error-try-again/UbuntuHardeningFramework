#!/bin/bash

# A script to harden an Ubuntu server.
function main() {
  set -e # Exit immediately if any command fails

  # Define the remote host
  local remote_host=""

  # Define the remote user
  local remote_user="ubuntu"

  local email_address=""

  # Define the remote SSH port
  local remote_port=$1

  # Define the new admin username
  local new_user="admin"

  local new_port="$1"

  local hardcoded_port="22"

  # Define configuration file paths
  local sshd_config="/etc/ssh/sshd_config"
  local fail2ban_jail_conf="/etc/fail2ban/jail.conf"
  local fail2ban_jail_local="/etc/fail2ban/jail.local"

  # Define helper functions
  source "helper_functions.sh"
  source "configure_automatic_updates.sh"
  source "disable_root_login.sh"

  local ssh_local_directory="/home/void/.ssh"

  local ssh_local_file="/home/void/.ssh/authorized_keys"

  local ssh_remote_directory="/home/ubuntu/.ssh"

  local ssh_remote_file="/home/ubuntu/.ssh/authorized_keys"

  local ssh_local_pem="$HOME/.ssh/jumpbox_aws_rsa.pem"

  export remote_host
  export remote_user
  export email_address
  export remote_port
  export new_user
  export new_port
  export hardcoded_port
  export sshd_config
  export fail2ban_jail_conf
  export fail2ban_jail_local
  export ssh_local_directory
  export ssh_local_file
  export ssh_remote_directory
  export ssh_remote_file
  export ssh_local_pem

  configure_automatic_updates

}

main "$@"
