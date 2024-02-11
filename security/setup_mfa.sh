#!/bin/bash

 # Configure SSH to use MFA
function configure_mfa() {
  echo "Configuring SSH to use MFA..."
  check_and_set_ssh_option "ChallengeResponseAuthentication" "yes"
  check_and_set_ssh_option "UsePAM" "yes"

  # Comment out the '@include common-auth' line in /etc/pam.d/sshd
  if ! run_remote_command "sudo -S sed -i '/^@include common-auth/s/^/#/' /etc/pam.d/sshd"; then
    echo "Error: Failed to comment out '@include common-auth' in /etc/pam.d/sshd"
    prompt_user_for_actions
  fi

  # Add the 'AuthenticationMethods publickey' line to /etc/ssh/sshd_config
  if ! run_remote_command "sudo -S sed -i '/^#.*AuthenticationMethods.*publickey/ s/^#//' /etc/ssh/sshd_config"; then
    echo "Error: Failed to add 'AuthenticationMethods publickey' to /etc/ssh/sshd_config"
    prompt_user_for_actions
  fi

  # Add the pam_google_authenticator.so line to the PAM configuration file for SSH
  if ! run_remote_command "sudo -S sh -c 'grep -q -F \"auth required pam_google_authenticator.so\" /etc/pam.d/sshd || \
                            echo \"auth required pam_google_authenticator.so\" >> /etc/pam.d/sshd'"; then
    echo "Error: Failed to configure PAM for MFA"
    prompt_user_for_actions
  fi

  echo "SSH is now configured to use MFA."
  prompt_user_for_actions
}

 # Enable MFA for the new admin user
function enable_mfa_for_admin_user() {
  echo "Enabling MFA..."

  # Run google-authenticator for the new admin user
  if ! run_remote_command "google-authenticator -t -d -f -r 1 -R 30 -W"; then
    echo "Error: Failed to enable MFA"
    prompt_user_for_actions
  fi

  # Check that the .google_authenticator file was created for the new admin user
  if ! run_remote_command "[[ -f ~/.google_authenticator ]]"; then
    echo "Error: Failed to enable MFA"
    prompt_user_for_actions
  fi

  echo "MFA enabled."
}

 # Setup MFA for SSH login
function setup_mfa() {
  # Check if MFA is already installed
  if run_remote_command "dpkg-query --show libpam-google-authenticator"; then
    echo "MFA is already installed."
  else
    # Install Google Authenticator
    echo "Installing Google Authenticator..."
    if ! run_remote_command "sudo -S apt-get update && sudo -S apt-get install libpam-google-authenticator -y"; then
      echo "Error: Failed to install Google Authenticator"
      prompt_user_for_actions
    fi
  fi

  enable_mfa_for_admin_user
  configure_mfa
}