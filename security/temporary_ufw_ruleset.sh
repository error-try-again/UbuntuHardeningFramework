#!/usr/bin/env bash

# Prints informational messages to stdout.
info() {
    echo "[INFO] $1"  # Echoes the input message prefixed with [INFO].
}

# Sets the UFW firewall to deny all incoming connections by default,
# but allows SSH connections to ensure remote access is maintained.
enable_strict_policy() {
    info "Enabling default deny policy and allowing SSH..."
    sudo ufw default deny incoming || { info "Failed to set default deny policy"; exit 1; }
    sudo ufw allow ssh || { info "Failed to allow SSH"; exit 1; }
    sudo ufw enable || { info "Failed to enable UFW"; exit 1; }
}

# Reverts the UFW firewall rules to allow all incoming connections
# and removes the previously added rule to allow SSH.
revert_policy() {
    info "Reverting to default policy (allow incoming)..."
    sudo ufw default allow incoming || { info "Failed to set default allow policy"; exit 1; }
    sudo ufw delete allow ssh || { info "Failed to delete SSH allow rule"; exit 1; }
}

# The main function where the script starts. It checks for the presence of
# a duration argument, applies a strict firewall policy, waits for the specified
# duration, and then reverts the firewall policy to its original state.
# Usage: main <duration_in_seconds>
main() {
    # Check if a duration argument is provided. If not, display usage information and exit.
    if [[ -z "$1" ]]; then
        info "Usage: $0 <duration_in_seconds>"
        exit 1
    fi

    local duration="$1"  # Store the first argument as the duration.

    info "Starting the firewall policy script..."
    enable_strict_policy  # Apply strict firewall policy.

    info "Strict policy will be reverted in ${duration} seconds."
    sleep "${duration}"  # Wait for the specified duration.

    revert_policy  # Revert the firewall policy to its original state.
    info "Firewall policy has been reverted. System is now using the default policy."
}

# Execute the main function, passing all the provided arguments.
main "$@"
