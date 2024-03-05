#!/usr/bin/env bash

set -euo pipefail

# Checks if the script is run as root and exits if not.
check_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
  fi
}

usage() {
  echo "Usage: $0 [canonical_sender] [mail_transfer_authority]"
  echo "Configures Postfix to use an external mail transfer authority for sending emails."
  echo "If canonical_sender is provided, it will be used to rewrite the sender address so that all emails appear to be sent from the provided address."
  exit 1
}

# Updates a configuration setting in the Postfix main.cf file.
update_postfix_config() {
  local setting_name="$1"
  local setting_value="$2"
  local main_cf="$3"

  if [[ -z ${setting_value} ]]; then
    echo "Value for ${setting_name} is not provided. Skipping update."
    return
  fi

  # Update or add the configuration in Postfix main.cf
  if grep -q "^${setting_name}" "${main_cf}"; then
    sed -i "s|^${setting_name}.*|${setting_name} = ${setting_value}|" "${main_cf}"
    echo "Updated ${setting_name} in ${main_cf}."
  else
    echo "${setting_name} = ${setting_value}" >> "${main_cf}"
    echo "Added ${setting_name} to ${main_cf}."
  fi
}

# Installs necessary packages and removes sendmail.
install_packages() {
  apt --purge remove sendmail -y && apt install postfix libsasl2-modules -y
  if [[ $? -ne 0 ]]; then
    echo "Package installation failed. Exiting."
    exit 1
  fi
}

# Verifies if the postdrop user exists in the system.
verify_postdrop() {
  if ! grep -q postdrop /etc/group; then
    echo "Postdrop user does not exist. Exiting."
    exit 1
  fi
}

# Configures postfix with required settings.
configure_postfix() {
  local main_cf="$1"
  local sasl_passwd="$2"
  local mail_transfer_authority="$3"

  \cp -f "${main_cf}"{.proto,}
  sed -i "s/^setgid_group =.*/setgid_group = postdrop/" "${main_cf}"
  postconf -e "relayhost = [${mail_transfer_authority}]:587" \
    "smtp_sasl_auth_enable = yes" \
    "smtp_sasl_security_options = noanonymous" \
    "smtp_sasl_password_maps = hash:${sasl_passwd}" \
    "smtp_use_tls = yes" \
    "smtp_tls_security_level = encrypt" \
    "smtp_tls_note_starttls_offer = yes" \
    "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt"
    enable_aliases
}

# Configure aliases for root user
enable_aliases() {
  local aliases_file="/etc/aliases"
  local aliases_db="/etc/aliases.db"

  if [[ ! -f ${aliases_file}   ]]; then
    touch "${aliases_file}"
  else
    postalias /etc/aliases
  fi

  if [[ ! -f ${aliases_db}   ]]; then
    newaliases
  fi
}

# Inserts the canonical sender configuration in main.cf to rewrite the sender address.
insert_sender_canonical() {
  local new_canonical_sender="$1"
  local sender_canonical_config_string="sender_canonical_maps = static:${new_canonical_sender}"
  if ! grep -q "${sender_canonical_config_string}" /etc/postfix/main.cf; then
    echo "${sender_canonical_config_string}" >> /etc/postfix/main.cf
  fi
}

# Starts postfix service if not already running.
start_postfix() {
  if ! systemctl is-active --quiet postfix; then
                                           echo "Starting Postfix service..."
                                                                               systemctl start postfix
  fi
}

# Configures the SASL password file.
configure_sasl_passwd() {
  local sasl_passwd="$1"
  local mail_transfer_authority="$2"
  local ses_port="${3:-587}"

  local smtp_user smtp_password
  read -p "Enter SMTP username: " smtp_user
  read -sp "Enter SMTP password: " smtp_password

  echo "[${mail_transfer_authority}]:${ses_port} ${smtp_user}:${smtp_password}" > "${sasl_passwd}"
  chown root:root "${sasl_passwd}"
  chmod 0600 "${sasl_passwd}"
  postmap -v hash:"${sasl_passwd}"

  unset smtp_user smtp_password
}

# Enables and restarts postfix, and checks its status.
enable_and_restart_postfix() {
  systemctl enable postfix --quiet
  systemctl restart postfix --quiet
  systemctl status postfix --no-pager
}

# Backup the Postfix configuration file, if it exists.
backup_configs() {
  local main_cf="$1"
  local backup_dir="/etc/postfix/backup"
  local backup_file
  backup_file="${backup_dir}/main.cf.$(date +%Y%m%d%H%M%S)"

  if [[ ! -d ${backup_dir}   ]]; then
    mkdir -p "${backup_dir}"
  fi

  if [[ -f ${main_cf}   ]]; then
    cp -f "${main_cf}" "${backup_file}"
    echo "Backup of ${main_cf} created at ${backup_file}."
  else
    echo "No backup created. ${main_cf} does not exist."
  fi
}

# Validate Postfix configuration.
validate_postfix_config() {
  echo "Validating Postfix configuration..."
  if ! postfix check; then
                     echo "Postfix configuration validation failed. Exiting."
                                                                               exit 1
  fi
  echo "Postfix configuration is valid."
}

# Main function to execute script tasks.
main() {
  check_root

  local backup=false
  local main_cf="/etc/postfix/main.cf"
  local sasl_passwd="/etc/postfix/sasl_passwd"

  if [[ $# -ne 2 ]]; then
    usage
  fi

  local canonical_sender="${1}"
  local mail_transfer_authority="${2:-email-smtp.ap-southeast-2.amazonaws.com}"

  install_packages
  start_postfix
  verify_postdrop

  configure_postfix "${main_cf}" "${sasl_passwd}" "${mail_transfer_authority}"
  update_postfix_config "sendmail_path" "$(which sendmail)" "${main_cf}"
  update_postfix_config "mailq_path" "$(which mailq)" "${main_cf}"
  update_postfix_config "newaliases_path" "$(which newaliases)" "${main_cf}"
  update_postfix_config "html_directory" "/usr/share/doc/postfix/html" "${main_cf}"
  update_postfix_config "manpage_directory" "/usr/share/man" "${main_cf}"
  update_postfix_config "sample_directory" "/usr/share/doc/postfix/samples" "${main_cf}"
  update_postfix_config "readme_directory" "/usr/share/doc/postfix/readme" "${main_cf}"

  insert_sender_canonical "${canonical_sender}"
  configure_sasl_passwd "${sasl_passwd}" "${mail_transfer_authority}"

  if [[ ${backup} == "true"   ]]; then
    backup_configs "${main_cf}"
  fi

  enable_and_restart_postfix
  validate_postfix_config
  enable_and_restart_postfix

  echo "Postfix configuration successfully completed."
}

main "$@"
