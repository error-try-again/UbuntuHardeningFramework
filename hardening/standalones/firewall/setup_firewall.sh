#!/usr/bin/env bash

set -euo pipefail

# Prints informational messages to stdout.
info() {
    echo "[INFO] $1"  # Echoes the input message prefixed with [INFO].
}

# Checks if UFW is installed and installs it if it is not.
install_ufw() {
    if ! command -v ufw &> /dev/null; then
        info "UFW is not installed. Installing..."
        sudo apt-get update -y || { info "Failed to update package list"; exit 1; }
        sudo apt-get install -y ufw || { info "Failed to install UFW"; exit 1; }
    else
        info "UFW is already installed."
    fi
}

# Sets the UFW firewall to deny all incoming connections by default,
# but allows SSH connections to ensure remote access is maintained.
enable_strict_policy() {
    info "Enabling default deny policy and allowing SSH..."
    sudo ufw default deny incoming || { info "Failed to set default deny policy"; exit 1; }
    sudo ufw allow ssh || { info "Failed to allow SSH"; exit 1; }
    sudo ufw --force enable || { info "Failed to enable UFW"; exit 1; }
}

main() {
    install_ufw
    enable_strict_policy
}

main "$@"