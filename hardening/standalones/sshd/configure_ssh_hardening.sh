#!/usr/bin/env bash

# Usage message
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  -p  Specify SSH port (default: 22)
  -u  Specify a comma-separated list of allowed users
  -f  Specify path to a file containing a list of users
EOF
    exit 1
}

# Validate SSH port
validate_ssh_port() {
    if ! [[ $ssh_port =~ ^[0-9]+$ ]] || (( ssh_port < 1 || ssh_port > 65535 )); then
        echo "Invalid SSH port specified. Exiting..." >&2
        exit 1
    fi
}

# Parse command line options for users list
parse_and_set_users() {
    if [[ -n $allow_users_list ]]; then
        echo "Using user list from command line."
    elif [[ -f $users_list_path ]]; then
        allow_users_list=$(tr '\n' ',' < "$users_list_path" | sed 's/,$//')
        echo "Using user list from file: $users_list_path."
    else
        echo "Error: No users specified for SSH access." >&2
        usage
    fi
}

# Backup the SSHD configuration file
backup_sshd_config() {
    echo "Creating backup of sshd_config at $backup_file..."
    cp "$sshd_config_file" "$backup_file" && echo "Backup created successfully." || {
        echo "Failed to create backup. Exiting..." >&2
        exit 1
    }
}

# Replace or append a configuration setting and remove duplicates
update_config() {
    local key="$1"
    local value="$2"
    local file="$3"

    # Use sed to first delete lines matching the key, then append the new setting
    # This handles removing both active and commented-out (duplicate) lines
    sed -i.bak "/^#*$key /d" "$file"
    echo "$key $value" >> "$file"
}

# Configure cryptographic settings
configure_crypto_settings() {
    echo "Configuring cryptographic settings..."
    update_config "KexAlgorithms" "curve25519-sha256@libssh.org" "$sshd_config_file"
    update_config "Ciphers" "aes256-ctr,aes192-ctr,aes128-ctr" "$sshd_config_file"
    update_config "MACs" "hmac-sha2-512,hmac-sha2-256" "$sshd_config_file"
    update_config "RekeyLimit" "default none" "$sshd_config_file"
}


# Apply basic configuration changes
apply_basic_config() {
    echo "Applying basic configuration..."
    ufw allow "$ssh_port" && echo "Firewall rule added for SSH port $ssh_port." || {
        echo "Failed to add firewall rule. Exiting..." >&2
        exit 1
    }
    update_config "Port" "$ssh_port" "$sshd_config_file"
}

# Apply configurations for AddressFamily, ListenAddress, and HostKey
configure_network_and_keys() {
    echo "Configuring network settings and host keys..."
    update_config "AddressFamily" "any" "$sshd_config_file"
    update_config "ListenAddress" "0.0.0.0" "$sshd_config_file"
    update_config "ListenAddress" "::" "$sshd_config_file"
    update_config "HostKey" "/etc/ssh/ssh_host_rsa_key" "$sshd_config_file"
    update_config "HostKey" "/etc/ssh/ssh_host_ed25519_key" "$sshd_config_file"
}

# Apply basic security settings
configure_basic_security() {
    echo "Applying basic security settings..."
    update_config "StrictModes" "yes" "$sshd_config_file"
    update_config "PubkeyAuthentication" "yes" "$sshd_config_file"
    update_config "PrintMotd" "no" "$sshd_config_file"
    update_config "Compression" "no" "$sshd_config_file"
    update_config "AcceptEnv" "LANG LC_*" "$sshd_config_file"
}

# Configure user authentication
configure_authentication_hardening() {
    echo "Hardening authentication settings..."
    update_config "AllowUsers" "$allow_users_list" "$sshd_config_file"
    update_config "AuthorizedKeysFile" ".ssh/authorized_keys" "$sshd_config_file"
    update_config "PermitEmptyPasswords" "no" "$sshd_config_file"
    update_config "PasswordAuthentication" "no" "$sshd_config_file"
    update_config "ChallengeResponseAuthentication" "no" "$sshd_config_file"
    update_config "UsePAM" "yes" "$sshd_config_file"
}

# Disable Weak Authentication and Unused Features
disable_weak_authentication_and_features() {
    echo "Disabling weak authentication methods and unused features..."
    update_config "HostbasedAuthentication" "no" "$sshd_config_file"
    update_config "IgnoreUserKnownHosts" "yes" "$sshd_config_file"
    update_config "PermitRootLogin" "no" "$sshd_config_file"
    update_config "AllowAgentForwarding" "no" "$sshd_config_file"
    update_config "AllowTcpForwarding" "no" "$sshd_config_file"
    update_config "GatewayPorts" "no" "$sshd_config_file"
    update_config "X11Forwarding" "no" "$sshd_config_file"
    update_config "PermitTTY" "no" "$sshd_config_file"
    update_config "TCPKeepAlive" "no" "$sshd_config_file"
}

# Apply security enhancements
configure_enhanced_security_settings() {
    echo "Applying security enhancements..."
    update_config "UseDNS" "no" "$sshd_config_file"
    update_config "MaxSessions" "3" "$sshd_config_file"
    update_config "IgnoreRhosts" "yes" "$sshd_config_file"
    update_config "PermitUserEnvironment" "no" "$sshd_config_file"
}

# Configure System and Logging
configure_system_and_logging() {
    echo "Configuring system and logging settings..."
    update_config "SyslogFacility" "AUTH" "$sshd_config_file"
    update_config "LogLevel" "INFO" "$sshd_config_file"
    update_config "PrintLastLog" "yes" "$sshd_config_file"
    update_config "MaxStartups" "10:30:100" "$sshd_config_file"
    update_config "Banner" "/etc/issue.net" "$sshd_config_file"
}

# Configure connection management settings
configure_connection_management() {
    echo "Configuring connection management settings..."
    update_config "ClientAliveInterval" "120" "$sshd_config_file"
    update_config "ClientAliveCountMax" "0" "$sshd_config_file"
    update_config "LoginGraceTime" "30s" "$sshd_config_file"
    update_config "MaxAuthTries" "2" "$sshd_config_file"
}

# Restart the SSHD service
restart_sshd() {
    echo "Restarting SSHD to apply changes..."
    if systemctl reload sshd; then
        echo "SSHD reloaded successfully."
    else
        echo "Reloading failed, attempting restart..." >&2
        if systemctl restart sshd; then
            echo "SSHD restarted successfully."
        else
            echo "Failed to restart SSHD. Please check manually." >&2
        fi
    fi
}

# Main function to parse options and apply configurations
main() {
    local opt
    while getopts ":p:u:f:h" opt; do
        case $opt in
            p) ssh_port="$OPTARG" ;;
            u) allow_users_list="$OPTARG" ;;
            f) users_list_path="$OPTARG" ;;
            h) usage; exit ;;
            *) usage; exit 1 ;;
        esac
    done

    ssh_port="${ssh_port:-22}" # Default SSH port
    sshd_config_file="/etc/ssh/sshd_config_back" # Correct path for sshd_config
    backup_file="${sshd_config_file}.bak"

    validate_ssh_port
    parse_and_set_users
    backup_sshd_config
    apply_basic_config
    configure_system_and_logging
    configure_network_and_keys
    configure_basic_security
    configure_authentication_hardening
    configure_enhanced_security_settings
    configure_connection_management
    configure_crypto_settings
    restart_sshd

    echo "SSH hardening configuration applied successfully."
}

main "$@"
