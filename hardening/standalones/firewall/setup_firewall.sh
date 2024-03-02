#!/usr/bin/env bash

set -euo pipefail

# Checks if the script is being run as root
check_root() {
  local uuid
  uuid=$(id -u)
  if [[ ${uuid} -ne 0 ]]; then
    echo "This script must be run as root. Exiting..." >&2
    exit 1
  fi
}

# Prints informational messages to stdout.
info() {
    echo "[INFO] $1"  # Echoes the input message prefixed with [INFO].
}

backup_file() {
    local file_path=$1

    local date
    date=$(date +%Y-%m-%d-%H-%M-%S)
    local backup_path="${file_path}.bak.${date}"
    if [[ -f "${file_path}" ]]; then
        info "Backing up ${file_path} to ${backup_path}..."
        cp "${file_path}" "${backup_path}" || { info "Failed to back up ${file_path}"; exit 1; }
    else
        info "${file_path} does not exist. No need to back it up."
    fi
}

# Update ICMP rules in the specified UFW before.rules file
update_icmp_iptables() {
  local ufw_before_rules="$1"

  # Ensure the UFW rules file exists
  if [[ ! -f "${ufw_before_rules}" ]]; then
    info "File ${ufw_before_rules} does not exist. Skipping ICMP blocking..."
    return 1
  fi

  info "File ${ufw_before_rules} exists. Modifying to block ICMP..."

  # Define the types of ICMP messages to be modified
  local icmp_types=("destination-unreachable" "source-quench" "time-exceeded" "parameter-problem" "echo-request")

  # Backup the original file before making changes
  cp "${ufw_before_rules}" "${ufw_before_rules}.bak"

  local icmp_type
  for icmp_type in "${icmp_types[@]}"; do
    # Check if an ACCEPT rule exists for the current ICMP type
    if grep -qE -- "--icmp-type ${icmp_type} -j ACCEPT" "${ufw_before_rules}"; then
      # Replace ACCEPT with DROP for the found rule
      sed -i "s/--icmp-type ${icmp_type} -j ACCEPT/--icmp-type ${icmp_type} -j DROP/g" "${ufw_before_rules}"
      info "Replaced ACCEPT with DROP for ICMP type: ${icmp_type}."
    else
      # If no specific ACCEPT rule exists, check for a DROP rule before adding
      if ! grep -qE -- "--icmp-type ${icmp_type} -j DROP" "${ufw_before_rules}"; then
        # Insert the DROP rule before COMMIT
        sed -i "/^COMMIT/i -A ufw-before-input -p icmp --icmp-type ${icmp_type} -j DROP" "${ufw_before_rules}"
        info "Inserted DROP rule for ICMP type: ${icmp_type}."
      fi
    fi
  done

  info "ICMP blocking rules have been updated in ${ufw_before_rules}."
}

# Checks if UFW is installed and installs it if it is not.
install_ufw() {
    if ! command -v ufw &> /dev/null; then
        info "UFW is not installed. Installing..."
        apt-get update -y || { info "Failed to update package list"; exit 1; }
        apt-get install -y ufw || { info "Failed to install UFW"; exit 1; }
    else
        info "UFW is already installed."
    fi
}

# Enable a strict policy for UFW
enable_strict_policy() {
    local ssh_port="$1"

    info "Enabling default deny policy and allowing SSH on a non-standard port..."

    # Specify the policy to deny all incoming connections by default
    ufw default deny incoming || { info "Failed to set default deny policy"; exit 1; }

    # Specify the policy to allow all outgoing connections by default
    ufw default allow outgoing || { info "Failed to set default allow policy"; exit 1; }

    # Enable logging to help diagnose issues
    ufw logging on || { info "Failed to enable logging"; exit 1; }

    # Increase the logging level to help diagnose issues
    ufw logging high || { info "Failed to set logging level"; exit 1; }

    ## Allow SSH connections on a non-standard port
    ufw allow "${ssh_port}"/tcp || { info "Failed to allow SSH on port ${ssh_port}"; exit 1; }

    # Rate limit SSH connections on the non-standard port to prevent brute force attacks
    ufw limit "${ssh_port}"/tcp || { info "Failed to rate limit SSH on port ${ssh_port}"; exit 1; }

    # Enable UFW with --force to avoid being prompted to confirm the changes
    ufw --force enable || { info "Failed to enable UFW"; exit 1; }
}

usage() {
    echo "Usage: $0 <ssh_port>"
    exit 1
}

main() {
    check_root

    if [[ $# -ne 1 ]]; then
        usage
    fi

    local ssh_port="${1}"

    install_ufw
    local ufw_before_rules="/etc/ufw/before.rules"
    backup_file "${ufw_before_rules}"
    update_icmp_iptables "${ufw_before_rules}"
    enable_strict_policy "${ssh_port}"
}

main "$@"