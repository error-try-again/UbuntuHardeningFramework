#!/usr/bin/env bash

set -euo pipefail

# Ensures the script is executed with root privileges. Exits if not.
check_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
  fi
}

# Backup a file before modification
backup_file() {
  local file_path="$1"
  if [[ -f ${file_path} ]]; then
    cp "${file_path}" "${file_path}.bak"
    echo "Backup of ${file_path} created."
  else
    echo "File ${file_path} does not exist. Skipping backup."
  fi
}

# Set a strong password policy
configure_password_policy() {
  local pwquality_config="$1"
  local login_defs="$2"
  local common_password="$3"

  echo "Configuring password policy..."
  apt-get install libpam-pwquality libpam-cracklib -y || {
    echo "Failed to install libpam-pwquality libpam-cracklib"
    exit 1
  }

  # Back up configuration files
  backup_file "${pwquality_config}"
  backup_file "${login_defs}"
  backup_file "${common_password}"

  # Define a helper function for setting configuration options without duplicating them
  set_config_option() {
    local key="$1"
    local value="$2"
    local file="$3"

    if ! grep -q "^${key} = ${value}" "$file"; then
      if grep -q "^${key} " "$file"; then
        sed -i "/^${key} /c\\${key} = ${value}" "$file"
      else
        echo "${key} = ${value}" >> "$file"
      fi
    fi
  }

  # Password length, requirements for digits, uppercase, lowercase, special characters, repeat characters, and classes
  # Negative integer values imposes 'at least' requirements (e.g. -1 means at least 1 digit that matches the dcredit requirement)
  # Positive integer values imposes 'at most' requirements (e.g. maxrepeat=3 means no more than 3 repeating characters)
  set_config_option "minlen" "24" "${pwquality_config}"
  set_config_option "retry" "3" "${pwquality_config}"
  set_config_option "dcredit" "-1" "${pwquality_config}"
  set_config_option "ucredit" "-1" "${pwquality_config}"
  set_config_option "lcredit" "-1" "${pwquality_config}"
  set_config_option "ocredit" "-1" "${pwquality_config}"
  set_config_option "maxrepeat" "3" "${pwquality_config}"
  set_config_option "maxclassrepeat" "3" "${pwquality_config}"

  # Enforce SHA512 for password hashing
  set_config_option "ENCRYPT_METHOD" "SHA512" "/etc/login.defs"

  # Configure PAM to enforce the password policy
  local pam_pwquality_line="password requisite pam_pwquality.so retry=3 minlen=24 ucredit=-1 dcredit=-1 ocredit=-1 lcredit=-1 maxrepeat=3 maxclassrepeat=3"

  # Ensure no duplicate pam_pwquality.so line
  if ! grep -qF -- "$pam_pwquality_line" "${common_password}"; then
    sed -i "/^password.*requisite.*pam_pwquality.so/c\\$pam_pwquality_line" "${common_password}"
  fi

  # Ensure no duplicate pam_pwhistory.so line
  # Password history enforcement - remember 5 last passwords, use_authtok - use the current password when changing the password (not prompting for the old password)
  if ! grep -q "pam_pwhistory.so" "${common_password}"; then
    echo "password required pam_pwhistory.so remember=5 use_authtok" >> "${common_password}"
  fi

  # Password aging settings
  {
    echo "PASS_MAX_DAYS 90"
                             echo "PASS_MIN_DAYS 7"
                                                     echo "PASS_WARN_AGE 7"
  }                                                                            >> "${login_defs}"

  echo "Password policy configured."
}

configure_faillock() {
  local common_auth="$1"
  local common_account="$2"

  backup_file "$common_auth"
  backup_file "$common_account"

  echo "Configuring faillock..."
  # Remove existing lines to avoid duplicates
  sed -i "/pam_faillock.so/d" "${common_auth}"

  # Pre-auth lines
  {
    echo "auth required pam_faillock.so preauth silent deny=5 unlock_time=1800"
    echo "auth [success=1 default=bad] pam_unix.so"
    echo "auth [default=die] pam_faillock.so authfail deny=5 unlock_time=1800"
    echo "auth optional pam_permit.so"
  } >> "${common_auth}"

  # Account lines
  sed -i "/pam_faillock.so/d" "${common_account}"
  echo "account required pam_faillock.so" >> "${common_account}"

  echo "Faillock configured."
}

# Main function
main() {

  local pwquality_config="/etc/security/pwquality.conf"
  local login_defs="/etc/login.defs"
  local common_password="/etc/pam.d/common-password"
  local common_auth="/etc/pam.d/common-auth"
  local common_account="/etc/pam.d/common-account"

  check_root
  configure_password_policy "${pwquality_config}" "${login_defs}" "${common_password}"
  configure_faillock "${common_auth}" "${common_account}"
}

main "$@"
