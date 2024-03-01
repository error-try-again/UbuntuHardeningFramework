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

# Adds specified SSH keys to a user's authorized_keys.
inject_public_keys() {
  # Ensure exactly two arguments are passed.
  if [[ $# -ne 2 ]]; then
    echo "Usage: $0 username 'key1 key2 key3 ...'"
    return 1
  fi

  local username="$1"
  local keys="$2"

  # Retrieve user's home directory.
  local home_directory
  home_directory=$(getent passwd "${username}" | cut -d: -f6)

  # Check if home directory was successfully retrieved.
  if [[ -z ${home_directory} || ! -d ${home_directory}     ]]; then
    echo "Unable to find or access the home directory for ${username}. Skipping..." >&2
  else
    echo "Home directory for ${username} found at: ${home_directory}"
  fi

  # Define .ssh directory and authorized_keys file paths.
  local ssh_directory
  ssh_directory="${home_directory}/.ssh"

  local authorized_keys_file
  authorized_keys_file="${ssh_directory}/authorized_keys"

  # Ensure .ssh directory exists, with proper permissions and ownership.
  if [[ ! -d ${ssh_directory}   ]]; then
    echo "Creating .ssh directory for ${username}..."
    mkdir -p "${ssh_directory}" && chmod 700 "${ssh_directory}"
    chown "${username}":"${username}" "${ssh_directory}"
  fi

  # Ensure authorized_keys file exists, with proper permissions.
  if [[ ! -f ${authorized_keys_file}   ]]; then
    echo "Creating authorized_keys file for ${username}..."
    touch "${authorized_keys_file}" && chmod 600 "${authorized_keys_file}"
    chown "${username}":"${username}" "${authorized_keys_file}"
  fi

  # Prepare a temporary file for new keys.
  local temp_file
  temp_file=$(mktemp) || {
    echo "Failed to create a temporary file. Exiting..." >&2
    exit 1
  }

  # Read each key and add it to the temporary file if it doesn't already exist.
  # TODO; test the authorized key file is cleared on multiple entries
  local key_added=0
  local key
  while IFS= read -r key; do
    if [[ -n ${key}   ]] && ! grep -q -F "${key}" "${authorized_keys_file}"; then
      echo "${key}" >> "${temp_file}"
      key_added=1
    else
      echo "Key already exists for ${username}: ${key}"
    fi
  done <<< "${keys}"

  # Append new keys to authorized_keys if any.
  if [[ ${key_added} -eq 1 ]]; then
    cat "${temp_file}" >> "${authorized_keys_file}"
    echo "Added new keys for ${username}."
  else
    echo "No new keys to add for ${username}."
  fi

}

# Injects public SSH keys into the authorized_keys file for each user in the map.
inject_keys_for_all_users() {
  echo "Injecting public keys for all users..."
  for username in "${!user_ssh_keys_map[@]}"; do
    local keys="${user_ssh_keys_map[${username}]}"
    # Handle keys as newline-separated strings

    if ! id "${username}" &> /dev/null; then
      echo "Moving to the next user..."
      continue
    else
      echo "Injecting keys for user: ${username}"
      inject_public_keys "${username}" "${keys}"
    fi

  done
}

# Overwrite a file with new mapping if it exists, or create a new file if it doesn't.
overwrite_file_with_new_mapping() {
  local key_to_check="$1"
  local mapping="$2"
  local flag="$3"

  if [[ -f ${key_to_check} && ${flag} -eq 0 ]]; then
    echo "${key_to_check} already exists."
    echo "Do you want to overwrite the ${key_to_check} with the defaults? (y/n)"
    local overwrite
    read -r overwrite
    if [[ ${overwrite} == "y" ]]; then
      echo "${mapping}" > "${key_to_check}"
    fi
  else
    echo "${mapping}" > "${key_to_check}"
    echo "${key_to_check} has been created."
  fi
}

# Update Issue.net file
update_issue_net() {
  cat << 'EOF' > /etc/issue.net
  +----------------------------------------------------+
  | This is a controlled access system. The activities |
  | on this system are heavily monitored.              |
  | Evidence of unauthorised activities will be        |
  | disclosed to the appropriate authorities.          |
  +----------------------------------------------------+
EOF
}

# Usage message
usage() {
  cat << EOF
# Usage
${0} [OPTIONS]

# Example
${0} -p 2222 -f /path/to/allowed_users.txt -k /path/to/allowed_users_keys.txt

# Options
  -p  Specify SSH port (default: 22) (optional)
  -f  Specify path to a file containing a list of allowed ssh users. The file should be a list of space separated usernames. (mandatory)
  -k  Specify path to a file containing a list of allowed users and mapped to their public keys. (mandatory)
  -h  Display this help message

# File Formats
allowed_user_keys.txt (username:ssh-rsa key1,key2,key3)

  void:ssh-rsa AAAAB3Nzwn...BnmkSBpiBsqQ== void@null
  admin:ssh-rsa AAAAB3Nzwn...BnmkSBpiBsqQ== void@null,ssh-ed2551 ...AAIDk7VFe example.eg@example.com

allowed_users.txt (user1,user2,user3)

  void,admin

EOF
}

# Validate SSH port number
validate_port() {
  if ! [[ ${1} =~ ^[0-9]+$ ]] || ((${1} < 1 || ${1} > 65535)); then
    echo "Invalid SSH port specified: ${1}. Exiting..." >&2
    exit 1
  fi
}

# Parse users and their keys from a comma-separated string or a file
# TODO: Clean up (separate logic into two distinct functions)
parse_user_ssh_keys() {
  local users_input="$1"
  local allowed_users_list_path="$2"

  echo "Parsing users and their keys..."

  # Parse users and keys from the input string
  local users
  IFS=' ' read -r -a users <<< "${users_input}"
  local user_pair
  for user_pair in "${users[@]}"; do
    local username keys
    username=$(echo "${user_pair}" | cut -d: -f1)
    # Keys are expected to be comma-separated for each user
    keys=$(echo "${user_pair}" | cut -d: -f2- | tr ',' '\n')
    user_ssh_keys_map["${username}"]="${keys}"
  done

  # Optionally, parse from a file if specified
  if [[ -n ${allowed_users_list_path} && -f ${allowed_users_list_path}     ]]; then
    local line
    while IFS= read -r line; do
      local username keys
      username=$(echo "${line}" | cut -d: -f1)
      # Again, handling comma-separated keys
      keys=$(echo "${line}" | cut -d: -f2- | tr ',' '\n')
      user_ssh_keys_map["${username}"]="${keys}"
    done < "${allowed_users_list_path}"
  fi
}

# Parse allowed SSH users from a comma-separated string or a file
parse_allowed_ssh_users() {
  echo "Parsing allowed SSH users..."

  # Declare an associative array locally within the function
  declare -A allowed_ssh_users

  # Check if a command-line argument is provided
  if [[ -n ${1-}   ]]; then
    local users_array
    IFS=',' read -r -a users_array <<< "$1"
    local user_entry
    for user_entry in "${users_array[@]}"; do
      local keys
      IFS=':' read -r username keys <<< "${user_entry}"
      allowed_ssh_users["${username}"]="${keys}"
    done

  # Check if a file path is provided and the file exists
  elif [[ -n ${2-} && -f $2     ]]; then
    while IFS=: read -r username keys; do
      allowed_ssh_users["${username}"]="${keys}"
    done < "$2"
  else
    echo "Error: No valid user input provided or file does not exist." >&2
    return 1
  fi

  # Print the parsed users and keys for verification
  local user
  for user in "${!allowed_ssh_users[@]}"; do
    echo "User: ${user}, Keys: ${allowed_ssh_users[${user}]}"
  done
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

# Verify the SSHD configuration file
verify_sshd_config() {
  local sshd_config_file="$1"
  if ! sshd -t -f "${sshd_config_file}"; then
    echo "Failed to verify the SSHD configuration. Check manually." >&2
    exit 1
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
append_totp_to_etc_bashrc() {
  mkdir -p /etc/ssh_login_scripts

  local totp_script="/etc/ssh_login_scripts/google_authenticator_totp_check.sh"

  if [[ -f ${totp_script} ]]; then
    echo "The TOTP profile script already exists."
  else
    cat << 'EOF' > "${totp_script}"
#!/usr/bin/env bash

# Logging function with error handling
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

  if grep -qE "${totp_script_execution_grep_query}" /etc/zsh/zprofile; then
    echo "TOTP profile script execution already exists in /etc/zsh/zprofile."
  else
    # Append script execution to /etc/zsh/zprofile
    echo "${totp_script_execution}" >> /etc/zsh/zprofile
    echo "TOTP profile script execution added to /etc/zsh/zprofile."
  fi

  # Check if the script execution already exists in /etc/profile
  if grep -qE "${totp_script_execution_grep_query}" /etc/profile; then
    echo "TOTP profile script execution already exists in /etc/profile."
  else
    # Append script execution to /etc/profile
    echo "${totp_script_execution}" >> /etc/profile
    echo "TOTP profile script execution added to /etc/profile."
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

# Generate a comma-separated list of allowed users from a file
generate_allow_users_list() {
  local allowed_users_list_path="$1"
  local allow_users_list=""

  # Check if the users list file exists and is readable
  if [[ -f ${allowed_users_list_path} && -r ${allowed_users_list_path} ]]; then
    # Placeholder to ignore the second field
    local rest
    # Read the file line by line and append the username to the allow_users_list
    while IFS=: read -r username rest; do
      if [[ -n ${username}   ]]; then
        # Append username to allow_users_list, separated by commas
        allow_users_list="${allow_users_list:+${allow_users_list},}${username}"
      fi
    done < "${allowed_users_list_path}"
  else
    echo "The specified users list file does not exist or cannot be read."
    return 1
  fi

  echo "${allow_users_list}"
}

# Apply multiple security configurations to the sshd_config file.
# This includes setting the SSH port, configuring user access, and securing the SSH daemon.
apply_configurations() {
  local ssh_port="$1"
  local sshd_config_file="/etc/ssh/sshd_config"

  echo "Applying SSH hardening configurations..."

  # Ensure there's a backup of the original sshd_config before making changes.
  backup_config "${sshd_config_file}"

  # Generate a space-separated list of allowed users from the file
  local allow_users_list
  allow_users_list=$(
                     IFS=' '  # Set the Internal Field Separator to space
                              echo "${allowed_ssh_users[*]}"
  )

  if [[ -z ${allow_users_list}   ]]; then
    echo "No users to allow via SSH. Check the users list file."
    return 1
  fi

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
  update_config "AllowUsers" "${allow_users_list}" "${sshd_config_file}"
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

# Restart SSHD to apply changes
restart_sshd() {
  if systemctl restart sshd; then
    echo "SSHD restarted successfully."
  else
    echo "Failed to restart SSHD. Check manually." >&2
    exit 1
  fi
}

# Main function
main() {
  check_root

  declare -Ag user_ssh_keys_map
  declare -Ag allowed_ssh_users

  local ssh_port="22"  # Default value, modify this for your system.

  local allowed_users_ssh_key_mapping allowed_users

  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  else
    local allowed_users_ssh_key_mapping="$1"
    local allowed_users="$2"
  fi

  # Default paths for allowed users and their keys if not specified via command-line arguments.
  local allowed_users_list_path="allowed_users.txt"
  local allowed_users_key_map_path="allowed_users_keys.txt"

  local opt
  local allowed_ssh_users_file_flag=0
  local allowed_ssh_key_map_file_flag=0
  while getopts ":p:u:f:k:h" opt; do
    case ${opt} in
      p)
        ssh_port="${OPTARG}"
        validate_port "${ssh_port}"
        ;;
      u) allowed_users_ssh_key_mapping="${OPTARG}" ;;
      f) allowed_users_list_path="${OPTARG}" allowed_ssh_users_file_flag=1 ;;
      k) allowed_users_key_map_path="${OPTARG}" allowed_ssh_key_map_file_flag=1 ;;
      h)
        print_usage
        exit 1
        ;;
      \?)
        echo "Invalid option: -${OPTARG}" >&2
        exit 1
        ;;
      :)
        echo "Option -${OPTARG} requires an argument." >&2
        exit 1
        ;;
      *)
        print_usage
        exit 1
        ;;
    esac
  done

  # Overwrite the default values for allowed users and their keys if the files do not exist or if the user chooses to overwrite them.
  overwrite_file_with_new_mapping "${allowed_users_list_path}" "${allowed_users}" "${allowed_ssh_users_file_flag}"
  overwrite_file_with_new_mapping "${allowed_users_key_map_path}" "${allowed_users_ssh_key_mapping}" "${allowed_ssh_key_map_file_flag}"

  # Parse the ssh user key mapping and the allowed users list.
  parse_user_ssh_keys "${allowed_users_ssh_key_mapping}" "${allowed_users_key_map_path}"
  parse_allowed_ssh_users "${allowed_users}" "${allowed_users_list_path}"

  # Inject the public keys provided via the user_ssh_keys_map into the authorized_keys file for each user.
  inject_keys_for_all_users

  # Apply the SSH hardening configurations to the sshd_config file.
  apply_configurations "${ssh_port}"

  update_issue_net
  install_google_authenticator
  append_totp_to_etc_bashrc
  configure_pam_for_2fa
  restart_sshd

  echo "SSH hardening configuration applied successfully."
}

main "$@"
