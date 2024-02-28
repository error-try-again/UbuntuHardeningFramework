#!/usr/bin/env bash

set -euo pipefail

# Generates an SSH key pair, updates known_hosts, and copies the public key to the server.
# Usage: ./this_script.sh <server> <username> <email>

# Generate a new ed25519 SSH key pair for the specified server and user.
generate_key_pair() {
  local server="$1"
  local user="$2"
  local email="$3"
    ssh-keygen -t ed25519 -f "${HOME}/.ssh/${server}-${user}" -q -N "" -C "${email}"
}

# Add the server's public key to the user's known_hosts file.
key_scan() {
  local server="$1"
  local username="$2"
  local user_known_hosts="${HOME}/.ssh/known_hosts_${username}"

  local temp_file
  temp_file="$(mktemp)"

  if ssh-keyscan -H "${server}" > "${temp_file}" 2>/dev/null; then
    if ! grep -F -f "${temp_file}" "${user_known_hosts}" > /dev/null; then
      cat "${temp_file}" >> "${user_known_hosts}"
      echo "Added ${server} to ${user_known_hosts}."
    else
      echo "${server} is already in ${user_known_hosts}."
    fi
  else
    echo "ssh-keyscan failed for ${server}."
    return 1
  fi

  rm -f "${temp_file}"
}

# Copy the public key to the server for the specified user.
copy_key_to_server() {
  local server="$1"
  local user="$2"
  local public_key_file="${HOME}/.ssh/${server}-${user}.pub"

  if ssh "${user}@${server}" "mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && cat >> ~/.ssh/authorized_keys" < "${public_key_file}" 2>/dev/null; then
    echo "Public key successfully copied to ${server} for user ${user}."
  else
    echo "Failed to copy public key to ${server} for user ${user}."
    return 1
  fi
}

# Main function.
main() {
  if [[ "$#" -ne 3 ]]; then
    echo "Usage: $0 <server> <username> <email>"
    exit 1
  fi

  local server="$1"
  local user="$2"
  local email="$3"

  generate_key_pair "${server}" "${user}" "${email}"
  key_scan "${server}" "${user}"
  copy_key_to_server "${server}" "${user}"
}

main "$@"
