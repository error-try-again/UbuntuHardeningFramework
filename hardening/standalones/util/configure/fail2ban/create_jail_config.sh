#!/usr/bin/env bash

# Create a custom Fail2ban jail configuration for SSH protection
create_jail_config() {
  local custom_jail="${1}"
  local ip_list="${2:-127.0.0.1}" # Default IP list to localhost if not provided

  # Check if parameters are provided
  if [[ -z ${custom_jail} ]]; then
    echo "Error: No file path provided for the jail configuration."
    return 1
  fi

    # Create a custom jail configuration for SSH if it doesn't exist
    cat <<- EOF > "${custom_jail}"
        [sshd]
        enabled = true
        port = ssh
        filter = sshd
        logpath = /var/log/auth.log
        maxretry = 3
        findtime = 600
        bantime = 3600
        ignoreip = ${ip_list}
        destemail = yane.neurogames@gmail.com, yane.karov@gmail.com
        sender = yane.karov@legendland.com.au
        sendername = Fail2Ban
        mta = sendmail
        action = %(action_mwl)s
EOF
}
