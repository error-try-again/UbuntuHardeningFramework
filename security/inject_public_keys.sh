#!/usr/bin/env bash

set -euo pipefail

# Adds specified SSH keys to user's authorized_keys.
inject_public_keys() {
  # Check correct number of arguments.
  if [[ $# -ne 2 ]]; then
    echo "Usage: $0 username 'key1 key2 key3 ...'"
    return 1
  fi

  local username="$1"
  local keys="$2"

  # Verify user exists.
  local user_entry
  user_entry=$(getent passwd "${username}")
  if [[ -z "${user_entry}" ]]; then
    echo "User ${username} does not exist."
    return 1
  fi

  # Determine user's home and .ssh directory paths.
  local home_directory
  home_directory=$(echo "${user_entry}" | cut -d: -f6)
  local ssh_directory="${home_directory}/.ssh"
  local authorized_keys_file="${ssh_directory}/authorized_keys"

  # Ensure .ssh directory exists with proper permissions.
  if [[ ! -d "${ssh_directory}" ]]; then
    mkdir -p "${ssh_directory}" || return 1
    chmod 700 "${ssh_directory}" || return 1
    chown "${username}":"${username}" "${ssh_directory}" || return 1
  fi

  # Ensure authorized_keys file exists.
  if [[ ! -f "${authorized_keys_file}" ]]; then
    touch "${authorized_keys_file}" || return 1
  fi

  # Ensure authorized_keys file has proper permissions and ownership.
  chmod 600 "${authorized_keys_file}" || return 1
  chown "${username}":"${username}" "${authorized_keys_file}" || return 1

  # Prepare for atomic update using a temp file.
  local temp_file
  temp_file=$(mktemp)
  trap 'rm -f "$temp_file"' EXIT

  # Check and append new keys to temp file if not already present.
  local existing_keys
  existing_keys=$(cat "${authorized_keys_file}")
  local key_added=0
  local public_keys_array
  IFS=' ' read -r -a public_keys_array <<< "${keys}"
  local key
  for key in "${public_keys_array[@]}"; do
    if ! grep -q -F "${key}" <<< "${existing_keys}"; then
      echo "${key}" >> "${temp_file}"
      key_added=1
    else
      echo "Key already exists for ${username}: ${key}"
    fi
  done

  # Update authorized_keys if new keys were added.
  if [[ ${key_added} -eq 1 ]]; then
    cat "${temp_file}" >> "${authorized_keys_file}"
    echo "Public keys successfully injected for ${username}."
  else
    echo "No new keys added for ${username}."
  fi

  return 0
}

