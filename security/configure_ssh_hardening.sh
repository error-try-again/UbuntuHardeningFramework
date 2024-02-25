#!/usr/bin/env bash

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
print_usage() {
  cat << EOF
  Usage: ${0} [OPTIONS]

  Options:
    -p  Specify SSH port (default: 22)
    -u  Specify a comma-separated list of allowed users
    -f  Specify path to a file containing a list of users
EOF
}

# Ensure script is run with root privileges
require_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root. Exiting..." >&2
    exit 1
  fi
}

# Validate SSH port number
validate_port() {
  if ! [[ ${1} =~ ^[0-9]+$ ]] || ((${1} < 1 || ${1} > 65535)); then
    echo "Invalid SSH port specified: ${1}. Exiting..." >&2
    exit 1
  fi
}

# Parse and validate users list
parse_users() {
  if [[ -n ${1} ]]; then
    IFS=',' read -r -a users_array <<< "${1}"
  elif [[ -f ${2} ]]; then
    readarray -t users_array < "${2}"
  else
    echo "Error: No users specified for SSH access." >&2
    exit 1
  fi
}

# Backup sshd_config file with dynamic naming
backup_config() {
  local timestamp
  timestamp=$(date +%Y%m%d%H%M%S)
  cp "${1}" "${1}.bak.$timestamp" || {
      echo "Failed to back-up ${1}. Exiting..." >&2
      exit 1
  }
  echo "Backup created at ${1}.bak.$timestamp"
}

# Update or append a configuration setting in a specified file.
# This function searches for a key in the given file, and if it exists, it updates the line.
# If the key does not exist, it appends a new line with the key and value.
update_config() {
  local key="$1"
  local value="$2"
  local file="$3"

  # Check if the key exists and is not commented out, then replace or append the value.
  if grep -qE "^#*$key " "$file"; then
    sed -i "/^#*$key /c\\$key $value" "$file"
  else
    echo "$key $value" >> "$file"
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

# Apply multiple security configurations to the sshd_config file.
# This includes setting the SSH port, configuring user access, and securing the SSH daemon.
apply_configurations() {
  local ssh_port="$1"
  local sshd_config_file="/etc/ssh/sshd_config"

  # Ensure there's a backup of the original sshd_config before making changes.
  backup_config "${sshd_config_file}"

  # Convert the users array into a comma-separated string for the AllowUsers setting.
  local allow_users_list
  allow_users_list=$(
                     IFS=','
                              echo "${users_array[*]}"
  )

  # General Security Settings
  update_config "StrictModes" "yes" "${sshd_config_file}"
  update_config "PermitEmptyPasswords" "no" "${sshd_config_file}"
  update_config "PermitRootLogin" "no" "${sshd_config_file}"
  update_config "PasswordAuthentication" "no" "${sshd_config_file}"
  update_config "ChallengeResponseAuthentication" "no" "${sshd_config_file}"
  update_config "UsePAM" "yes" "${sshd_config_file}"

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
  require_root

  local ssh_port="22"
  local allow_users_list=""
  local users_list_path=""

  local opt
  while getopts ":p:u:f:h" opt; do
    case ${opt} in
      p)
        ssh_port="${OPTARG}"
        validate_port "${ssh_port}"
        ;;
      u) allow_users_list="${OPTARG}" ;;
      f) users_list_path="${OPTARG}" ;;
      h)
        print_usage
        exit
        ;;
      \?)
        echo "Invalid option: -${OPTARG}" >&2
        exit 1
        ;;
      :)
        echo "Option -${OPTARG} requires an argument." >&2
        exit 1
        ;;
    esac
  done

  parse_users "${allow_users_list}" "${users_list_path}"
  update_issue_net
  apply_configurations "${ssh_port}"
  restart_sshd

  echo "SSH hardening configuration applied successfully."
}

main "$@"