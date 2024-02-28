#!/usr/bin/env bash

set -euo pipefail

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
