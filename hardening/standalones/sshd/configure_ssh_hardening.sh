#!/usr/bin/env bash

set -euo pipefail

# Ensure script is run with root privileges
check_root() {
  local uuid
  uuid=$(id -u)
  if [[ ${uuid} -ne 0 ]]; then
    echo "This script must be run as root. Exiting..." >&2
    exit 1
  fi
}

# Usage message
usage() {
  cat << EOF
# Usage
${0} <allowed_users_ssh_key_mapping> <allowed_users_list>

# Formats
 (username:ssh-rsa key1,key2,key3)
 void:ssh-rsa AAAAB3Nzwn...BnmkSBpiBsqQ== void@null
 admin:ssh-rsa AAAAB3Nzwn...BnmkSBpiBsqQ== void@null,ssh-ed2551 ...AAIDk7VFe example.eg@example.com

(user1,user2,user3)
 void,admin

EOF
}

# Backup sshd_config file with dynamic naming
backup_config() {
  local timestamp
  timestamp=$(date +%Y%m%d%H%M)
  cp "${1}" "${1}.bak.${timestamp}" || {
      echo "Failed to back-up ${1}. Exiting..." >&2
      exit 1
  }
  echo "Backup created at ${1}.bak.${timestamp}"
}

# Validate SSH port number
validate_port() {
  if ! [[ ${1} =~ ^[0-9]+$ ]] || ((${1} < 1 || ${1} > 65535)); then
    echo "Invalid SSH port specified: ${1}. Exiting..." >&2
    exit 1
  fi
}

# Restart SSHD to apply changes
restart_sshd() {
  if systemctl restart sshd; then
    echo "SSHD restarted successfully."
  else
    echo "Failed to restart SSHD. Check manually." >&2
    exit 1
  fi
}

# Verify the SSHD configuration file
verify_sshd_config() {
  local sshd_config_file="$1"
  if ! sshd -t -f "${sshd_config_file}"; then
    echo "Failed to verify the SSHD configuration. Check manually." >&2
    exit 1
  fi
}

# Update Issue.net file
update_issue_net() {
echo "Updating /etc/issue.net..."
  cat << 'EOF' > /etc/issue.net
  +----------------------------------------------------+
  | This is a controlled access system. The activities |
  | on this system are heavily monitored.              |
  | Evidence of unauthorised activities will be        |
  | disclosed to the appropriate authorities.          |
  +----------------------------------------------------+
EOF
}

# Inject public keys for a specified user
inject_public_keys() {
  local username="$1"
  local keys="$2"

  # Retrieve the home directory of the user.
  local home_directory
  home_directory=$(getent passwd "${username}" | cut -d: -f6)

  # Ensure the home directory exists.
  if [[ -z "${home_directory}" || ! -d "${home_directory}" ]]; then
    echo "Unable to find or access the home directory for ${username}. Skipping..." >&2
  fi

  local ssh_dir="${home_directory}/.ssh"
  local auth_keys_file="${ssh_dir}/authorized_keys"

  # Create the .ssh directory and authorized_keys file if they don't exist.
  mkdir -p "${ssh_dir}" && chmod 700 "${ssh_dir}"
  touch "${auth_keys_file}" && chmod 600 "${auth_keys_file}"

  # Ensure the ownership is correct.
  chown "${username}":"${username}" "${ssh_dir}" "${auth_keys_file}"

  # Split keys by comma and iterate over them
  IFS=',' read -ra ADDR <<< "${keys}"
  local key
  for key in "${ADDR[@]}"; do
    # Trim any leading or trailing whitespace from the key
    key=$(echo "${key}" | xargs)
    # Append key to authorized_keys, avoiding duplicates.
    if ! grep -qxF -- "${key}" "${auth_keys_file}"; then
      echo "${key}" >> "${auth_keys_file}"
      echo "Added key for ${username}"
    else
      echo "Key already exists for ${username}"
    fi
  done
}

# Inject public keys for all users in the user_ssh_keys_map
inject_keys_for_all_users() {
  local user
  for user in "${!user_ssh_keys_map[@]}"; do
    if id -u "${user}" &>/dev/null; then
      echo "Injecting keys for user: ${user}"
    else
      echo "User ${user} does not exist. Skipping..."
      continue
    fi
    inject_public_keys "${user}" "${user_ssh_keys_map[${user}]}"
  done
}

# Parse the user and SSH key mappings from the provided string.
parse_user_ssh_keys() {
  echo "Parsing users and their keys from provided mappings..."

  # The variable contains newlines to separate users; process each line.
  while IFS= read -r line; do
    # Extract the username and keys, separated by the first colon.
    local username="${line%%:*}"
    local keys="${line#*:}"

    # Replace newlines in keys with commas for uniformity.
    keys="${keys//$'\n'/,}"

    # Populate the associative array.
    user_ssh_keys_map["${username}"]="${keys}"
  done <<< "${1}"
}


# Parse allowed SSH users from a comma-separated string
parse_allowed_ssh_users() {
  echo "Parsing allowed SSH users..."
  # If command-line list is provided
  if [[ -n $1   ]]; then
    local users_array
    IFS=',' read -r -a users_array <<< "$1"
    # Add the users to the allowed SSH users array with a space separator for the configuration file
    allowed_ssh_users=$(printf "%s " "${users_array[@]}")
  fi
}

# Update or append a configuration setting in a specified file.
# This function searches for a key in the given file, and if it exists, it updates the line.
# If the key does not exist, it appends a new line with the key and value.
update_config() {
  local key="$1"
  local value="$2"
  local file="$3"

  # Check if the key exists and is not commented out, then replace or append the value.
  if grep -qE "^#*${key} " "${file}"; then
    sed -i "/^#*${key} /c\\${key} ${value}" "${file}"
  else
    echo "${key} ${value}" >> "${file}"
  fi
}

# Install the Google Authenticator PAM module
install_google_authenticator() {
    echo "Updating system packages..."
    apt-get update -y
    echo "Installing Google Authenticator PAM module..."
    apt-get install libpam-google-authenticator -y
}

# Append TOTP profile script execution to /etc/profile
append_totp_to_profile() {
  mkdir -p /etc/ssh_login_scripts

  local totp_script="/etc/ssh_login_scripts/google_authenticator_totp_check.sh"

  if [[ -f ${totp_script} ]]; then
    echo "The TOTP profile script already exists."
  else
    cat << 'EOF' > "${totp_script}"
#!/usr/bin/env bash

# Logging function with error handling
log_event() {
  local current_time
  current_time=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[${current_time}] $1" | tee -a "${log_file}" >&2
}

# Check for all required commands at the start
check_dependencies() {
  local missing_commands=()
  local cmd
  for cmd in "$@"; do
    if ! command -v "${cmd}" &>/dev/null; then
      missing_commands+=("${cmd}")
    fi
  done

  if [[ ${#missing_commands[@]} -ne 0 ]]; then
    local cmd
    for cmd in "${missing_commands[@]}"; do
      echo "Required command '${cmd}' not found. Please install it." >&2
    done
    log_event "Missing commands: ${missing_commands[*]}. Aborting."
    exit 1
  fi
}

# Skip TOTP setup, log the event and exit
skip_totp_setup() {
  local user
  user=$(whoami)
  echo "Skipping TOTP setup."
  log_event "Skipping TOTP setup for ${user}."
  exit 0
}

# Checks if the script is being run as root
check_root() {
  local uuid
  uuid=$(id -u)
  if [[ ${uuid} -eq 0 ]]; then
    skip_totp_setup
  fi
}

# Set up TOTP using Google Authenticator with improved error handling
configure_totp() {
  if [[ -f "${HOME}/.google_authenticator" ]]; then
    echo "TOTP is already configured."
    log_event "TOTP configuration found. No action needed."
  else
    echo "TOTP is not configured. Setting up TOTP..."
    echo -e "To complete setup:\n1. Install the Google Authenticator app.\n2. Select 'Begin setup' > 'Scan a barcode'.\n3. Scan the QR code displayed.\n4. Follow the app instructions."
    if google-authenticator -t -d -f -r 3 -R 30 -W; then
      log_event "TOTP setup completed."
    else
      log_event "Error creating TOTP token."
      exit 2
    fi
  fi
}

# Main function
main() {
  check_root
  log_file="${HOME}/google_auth_setup.log"
  check_dependencies "google-authenticator"
  configure_totp
}

main "$@"
EOF
    chmod +x "${totp_script}"
  fi

  local totp_script_execution="source ${totp_script}"
  local totp_script_execution_grep_query="^#*source ${totp_script}"

  if [[ -f /etc/zsh/zprofile ]]; then
    if grep -qE "${totp_script_execution_grep_query}" /etc/zsh/zprofile; then
      echo "TOTP profile script execution already exists in /etc/zsh/zprofile."
    else
      # Append script execution to /etc/zsh/zprofile
      echo "${totp_script_execution}" >> /etc/zsh/zprofile
      echo "TOTP profile script execution added to /etc/zsh/zprofile."
    fi
  fi

  if [[ -f /etc/profile ]]; then
    if grep -qE "${totp_script_execution_grep_query}" /etc/profile; then
      echo "TOTP profile script execution already exists in /etc/profile."
    else
      # Append script execution to /etc/profile
      echo "${totp_script_execution}" >> /etc/profile
      echo "TOTP profile script execution added to /etc/profile."
    fi
  fi
}

# Configure PAM for 2FA
configure_pam_for_2fa() {
    local sshd_pam_config="/etc/pam.d/sshd"
    local pam_common_auth_string="@include common-auth"
    local pam_common_auth_grep_query="^#*@include common-auth"

    local pam_auth_required_permit_login_string="auth required pam_permit.so"
    local pam_auth_required_permit_login_grep_query="^#*auth required pam_permit.so"

    local pam_google_authenticator_string="auth required pam_google_authenticator.so nullok"
    local pam_google_authenticator_grep_query="^#*auth required pam_google_authenticator.so nullok"

    backup_config "${sshd_pam_config}"

    # Comment out the common-session include line if it exists
    sed -i "s/${pam_common_auth_grep_query}/#${pam_common_auth_string}/" "${sshd_pam_config}"

    # Allow login without TOTP for the first time
    grep -qE "${pam_auth_required_permit_login_grep_query}" "${sshd_pam_config}" || echo "${pam_auth_required_permit_login_string}" >> "${sshd_pam_config}"

    # Add the Google Authenticator PAM module to the SSHD PAM configuration
    grep -qE "${pam_google_authenticator_grep_query}" "${sshd_pam_config}" || echo "${pam_google_authenticator_string}" >> "${sshd_pam_config}"
}

# Apply multiple security configurations to the sshd_config file.
# This includes setting the SSH port, configuring user access, and securing the SSH daemon.
apply_configurations() {
  local ssh_port="$1"
  local sshd_config_file="/etc/ssh/sshd_config"

  echo "Applying SSH hardening configurations..."

  # Ensure there's a backup of the original sshd_config before making changes.
  backup_config "${sshd_config_file}"

  # General Security Settings
  update_config "StrictModes" "yes" "${sshd_config_file}"
  update_config "PermitEmptyPasswords" "no" "${sshd_config_file}"
  update_config "PermitRootLogin" "no" "${sshd_config_file}"
  update_config "UsePAM" "yes" "${sshd_config_file}"

  #2FA Related
  update_config "PasswordAuthentication" "no" "${sshd_config_file}"
  update_config "ChallengeResponseAuthentication" "yes" "${sshd_config_file}"
  update_config "KbdInteractiveAuthentication" "yes" "${sshd_config_file}"
  update_config "AuthenticationMethods" "publickey,keyboard-interactive" "${sshd_config_file}"

  # Logging and Monitoring
  update_config "SyslogFacility" "AUTH" "${sshd_config_file}"
  update_config "LogLevel" "VERBOSE" "${sshd_config_file}"
  update_config "PrintLastLog" "yes" "${sshd_config_file}"
  update_config "MaxStartups" "10:30:100" "${sshd_config_file}"

  # SSH Banner
  update_config "Banner" "/etc/issue.net" "${sshd_config_file}"

  # Network and System Settings
  update_config "AddressFamily" "any" "${sshd_config_file}"
  update_config "ListenAddress" "0.0.0.0" "${sshd_config_file}"
  update_config "PidFile" "/var/run/sshd.pid" "${sshd_config_file}"
  update_config "VersionAddendum" "none" "${sshd_config_file}"

  # Authentication and Access Settings
  update_config "PubkeyAuthentication" "yes" "${sshd_config_file}"
  update_config "AuthorizedKeysFile" ".ssh/authorized_keys" "${sshd_config_file}"
  update_config "AllowUsers" "${allowed_ssh_users[*]}" "${sshd_config_file}"
  update_config "MaxAuthTries" "3" "${sshd_config_file}"
  update_config "MaxSessions" "3" "${sshd_config_file}"

  # Connection and Session Settings
  update_config "ClientAliveInterval" "120" "${sshd_config_file}"
  update_config "ClientAliveCountMax" "0" "${sshd_config_file}"
  update_config "LoginGraceTime" "30s" "${sshd_config_file}"
  update_config "TCPKeepAlive" "no" "${sshd_config_file}"
  update_config "Port" "${ssh_port}" "${sshd_config_file}"

  # Interactive Shell
  update_config "PermitTTY" "yes" "${sshd_config_file}"

  # Feature Restrictions
  update_config "X11Forwarding" "no" "${sshd_config_file}"
  update_config "AllowTcpForwarding" "no" "${sshd_config_file}"
  update_config "GatewayPorts" "no" "${sshd_config_file}"
  update_config "UseDNS" "no" "${sshd_config_file}"
  update_config "PermitTunnel" "no" "${sshd_config_file}"

  # Additional Security Enhancements
  update_config "IgnoreRhosts" "yes" "${sshd_config_file}"
  update_config "HostbasedAuthentication" "no" "${sshd_config_file}"
  update_config "IgnoreUserKnownHosts" "yes" "${sshd_config_file}"
  update_config "PermitUserEnvironment" "no" "${sshd_config_file}"
  update_config "AllowAgentForwarding" "no" "${sshd_config_file}"
  update_config "Compression" "no" "${sshd_config_file}"
  update_config "PrintMotd" "no" "${sshd_config_file}"
  update_config "AcceptEnv" "LANG LC_*" "${sshd_config_file}"

  # Host Key Algorithms
  update_config "HostKey" "/etc/ssh/ssh_host_ed25519_key" "${sshd_config_file}"
  update_config "HostKey" "/etc/ssh/ssh_host_rsa_key" "${sshd_config_file}"
  update_config "HostKey" "/etc/ssh/ssh_host_ecdsa_key" "${sshd_config_file}"

  # Update KexAlgorithms, Ciphers, and MACs
  update_config "KexAlgorithms" "curve25519-sha256@libssh.org" "${sshd_config_file}"
  update_config "Ciphers" "aes256-ctr,aes192-ctr,aes128-ctr" "${sshd_config_file}"
  update_config "MACs" "hmac-sha2-512,hmac-sha2-256" "${sshd_config_file}"

  # Extra Rules (Breaking)
  #  update_config "ListenAddress" "::" "${sshd_config_file}"
  #  update_config "ChrootDirectory" "/etc/ssh/chroot" "${sshd_config_file}"

  # Remove any duplicate lines from the file
  awk '!seen[$0]++' "${sshd_config_file}" > "${sshd_config_file}.tmp" && mv "${sshd_config_file}.tmp" "${sshd_config_file}"

  # Verify the SSHD configuration file
  verify_sshd_config "${sshd_config_file}"
}

# Main function
main() {
  check_root

  if [[ $# -ne 2 ]]; then
    usage
    exit 1
  fi

  local allowed_users_ssh_key_mapping="$1"
  local allowed_users="$2"

  # Initialize associative arrays
  declare -Ag user_ssh_keys_map
  declare -Ag allowed_ssh_users

  # Parse the SSH user key mapping and the allowed users list.
  parse_user_ssh_keys "${allowed_users_ssh_key_mapping}"
  parse_allowed_ssh_users "${allowed_users}"

  # Proceed with SSH configuration and key injection
  inject_keys_for_all_users

  apply_configurations 22

  # Additional configurations and service restart
  update_issue_net
  install_google_authenticator
  append_totp_to_profile
  configure_pam_for_2fa
  restart_sshd

  echo "SSH hardening configuration applied successfully."
}

main "$@"
