#!/bin/bash

 # Check if fail2ban is installed & configure
function configure_fail2ban() {

  if ! run_remote_command "sudo -S fail2ban-client --version"; then
    echo "Fail2ban is not installed. Installing..."
    run_remote_command "sudo -S apt-get update && sudo -S apt-get install -y fail2ban"
  fi

  echo "Configuring Fail2ban..."
  if ! run_remote_command "sudo -S cp ${fail2ban_jail_conf} ${fail2ban_jail_local} &&
sudo -S sed -i 's/bantime = 10m/bantime = 1h/g' ${fail2ban_jail_local} &&
sudo -S sed -i 's/destemail = root@localhost/destemail = ${email_address}/g' ${fail2ban_jail_local} &&
sudo -S systemctl restart fail2ban"; then
    echo "Failed to configure Fail2ban. Retrying..."
    configure_fail2ban
  else
    echo "+++++++++++++++++++++++++"
    echo "Fail2ban configured successfully!"
    echo "+++++++++++++++++++++++++"
    prompt_user_for_actions
  fi
}
