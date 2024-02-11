#!/usr/bin/env bash

set -euo pipefail

# Utility function to check if a command exists.
check_command() {
  local cmd="$1"
  if ! command -v "${cmd}" &> /dev/null; then
    echo "${cmd} is not installed. Please install it before proceeding."
    exit 1
  fi
}

# Encrypts the SMTP credentials file for security.
encrypt_credentials() {
  local credentials_file="$1"
  check_command gpg
  echo "Encrypting SMTP credentials file..."
  gpg -v --symmetric --cipher-algo AES256 "${credentials_file}"
  echo "Credentials file encrypted."
  rm -f "${credentials_file}" # Remove plaintext file after encryption
}

# Reads and decrypts SMTP credentials from an encrypted file.
decrypt_and_read_credentials() {
  local credentials_file="$1"
  local encrypted_file="${credentials_file}.gpg"
  check_command gpg
  if [[ -f "${encrypted_file}" ]]; then
    echo "Decrypting SMTP credentials file..."
    gpg --yes --decrypt --output "${credentials_file}" "${encrypted_file}"
    smtp_user=$(grep 'smtp_user' "${credentials_file}" | cut -d'=' -f2)
    smtp_password=$(grep 'smtp_password' "${credentials_file}" | cut -d'=' -f2)
    rm -f "${credentials_file}" # Remove decrypted file after reading
  else
    echo "Encrypted SMTP credentials file not found. Exiting."
    exit 1
  fi
}

# Reads SMTP credentials from an external file or prompts the user.
# Saves and encrypts the credentials if entered manually.
read_smtp_credentials() {
  local credentials_file="$1"

  if [[ -f "${credentials_file}.gpg" ]]; then
    # Decrypt and read credentials
    decrypt_and_read_credentials "${credentials_file}"
  elif [[ -f "${credentials_file}" ]]; then
    # Read credentials from plaintext file (legacy support)
    smtp_user=$(grep 'smtp_user' "${credentials_file}" | cut -d'=' -f2)
    smtp_password=$(grep 'smtp_password' "${credentials_file}" | cut -d'=' -f2)

    encrypt_credentials "${credentials_file}"
  else
    # Prompt for credentials and save them
    read -p "Enter SMTP username: " smtp_user
    read -p "Enter SMTP password: " -s smtp_password
    echo

    # Save and encrypt credentials
    echo "smtp_user=${smtp_user}" > "${credentials_file}"
    echo "smtp_password=${smtp_password}" >> "${credentials_file}"

    encrypt_credentials "${credentials_file}"
  fi

  if [[ -z "${smtp_user}" || -z "${smtp_password}" ]]; then
    echo "SMTP credentials not provided. Exiting."
    exit 1
  fi

}

# Updates a configuration setting in the Postfix main.cf file.
update_postfix_config() {
  local setting_name="$1"
  local setting_value="$2"
  local main_cf="$3"

  if [[ -z "${setting_value}" ]]; then
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

# Checks if the script is run as root and exits if not.
check_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
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
  local ses_mta="$3"

  \cp -f "${main_cf}"{.proto,}
  sed -i "s/^setgid_group =.*/setgid_group = postdrop/" "${main_cf}"
  postconf -e "relayhost = [${ses_mta}]:587" \
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

  if [[ ! -f "${aliases_file}" ]]; then
    touch "${aliases_file}"
  else
    postalias /etc/aliases
  fi

  if [[ ! -f "${aliases_db}" ]]; then
    newaliases
  fi
}

# Inserts the canonical sender configuration in main.cf to rewrite the sender address.
insert_sender_canonical() {
  local new_canonical_sender="yane.karov@legendland.com.au"
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

# Clear SMTP credentials from memory
clear_smtp_credentials() {
  unset smtp_user smtp_password
}

# Configures the SASL password file.
configure_sasl_passwd() {
  local sasl_passwd="$1"
  local ses_mta="$2"
  local ses_port="587"

  echo "[${ses_mta}]:${ses_port} ${smtp_user}:${smtp_password}" > "${sasl_passwd}"
  chown root:root "${sasl_passwd}"
  chmod 0600 "${sasl_passwd}"
  postmap -v hash:"${sasl_passwd}"
}

# Enables and restarts postfix, and checks its status.
enable_and_restart_postfix() {
  systemctl enable postfix --quiet
  systemctl restart postfix --quiet
  systemctl status postfix --no-pager
}

# Backup configuration files.
backup_configs() {
  local main_cf="$1"
  \cp -rf "${main_cf}" "${main_cf}.bak"
  echo "Backup of configuration files completed."
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
  local backup=false
  local main_cf="/etc/postfix/main.cf"
  local sasl_passwd="/etc/postfix/sasl_passwd"
  local ses_mta="email-smtp.ap-southeast-2.amazonaws.com"
  local credentials_file="smtp_credentials.conf"

  check_root
  local opt
  while getopts ":c:b" opt; do
    case ${opt} in
      c) credentials_file=${OPTARG} ;;
      b)
        backup=true
        ;;
      \?)
         echo "Usage: cmd [-c] <credentials_file> [-b]"
                                                         exit 1
                                                                ;;
      *)
         echo "Invalid option: -${OPTARG}"
                                          exit 1
                                                 ;;
    esac
  done

  install_packages
  start_postfix
  verify_postdrop

  read_smtp_credentials "${credentials_file}"
  configure_postfix "${main_cf}" "${sasl_passwd}" "${ses_mta}"

  update_postfix_config "sendmail_path" "$(which sendmail)" "${main_cf}"
  update_postfix_config "mailq_path" "$(which mailq)" "${main_cf}"
  update_postfix_config "newaliases_path" "$(which newaliases)" "${main_cf}"
  update_postfix_config "html_directory" "/usr/share/doc/postfix/html" "${main_cf}"
  update_postfix_config "manpage_directory" "/usr/share/man" "${main_cf}"
  update_postfix_config "sample_directory" "/usr/share/doc/postfix/samples" "${main_cf}"
  update_postfix_config "readme_directory" "/usr/share/doc/postfix/readme" "${main_cf}"

  # Ensures that all mail is sent from the same address
  insert_sender_canonical

  configure_sasl_passwd "${sasl_passwd}" "${ses_mta}"

  [[ ${backup} == "true" ]] && backup_configs "${main_cf}"

  enable_and_restart_postfix
  validate_postfix_config
  enable_and_restart_postfix
  clear_smtp_credentials

  echo "Postfix configuration successfully completed."
}

main
