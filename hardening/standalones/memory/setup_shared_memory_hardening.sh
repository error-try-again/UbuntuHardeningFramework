#!/usr/bin/env bash

set -euo pipefail

# Enhances the security of /run/shm by setting 'noexec', 'nosuid', 'nodev' options.
# Ensures these settings persist after reboot by updating /etc/fstab. Requires root privileges.

# Checks if the script is being run as root
check_root() {
  if [[ ${EUID} -ne 0   ]]; then
    echo "Please run as root"
    exit 1
  fi
}

# Backs up /etc/fstab with a timestamp.
backup_fstab() {
  local backup_path
  backup_path="/etc/fstab.backup.$(date +%Y%m%d-%H%M%S)"
  echo "Backing up /etc/fstab to ${backup_path}..."
  cp /etc/fstab "${backup_path}" || {
    echo "Failed to back up /etc/fstab." >&2
    exit 1
  }
  echo "Backup created successfully."
}

# Updates or adds the fstab entry for /run/shm with secure options.
update_fstab() {
  local entry="tmpfs /run/shm tmpfs defaults,noexec,nosuid,nodev 0 0"
  echo "Ensuring secure options for /run/shm in /etc/fstab..."

  # Replace existing entry with secure options or add if not present.
  if grep -qE "^tmpfs /run/shm tmpfs" /etc/fstab; then
    sed -i "\|^tmpfs /run/shm tmpfs|c\\${entry}" /etc/fstab
  else
    echo "${entry}" >> /etc/fstab
  fi

  echo "/etc/fstab updated."
}

# Remounts /run/shm to apply the new options.
remount_shared_memory() {
  if mount -o remount /run/shm; then
    echo "Shared memory remounted successfully."
  else
    echo "Failed to remount /run/shm." >&2
    exit 1
  fi
}

# Validates the secure configuration of /run/shm.
validate_config() {
  echo "Validating shared memory configuration..."
  local mount_options
  mount_options=$(findmnt -n -o OPTIONS /run/shm)

  local option
  for option in noexec nosuid nodev; do
    if [[ ! "${mount_options}" = *"${option}"* ]]; then
      echo "Validation failed: /run/shm missing ${option} option." >&2
      exit 1
    fi
  done

  echo "Shared memory is secured correctly."
}

main() {
  check_root
  backup_fstab
  update_fstab
  remount_shared_memory
  validate_config
}

main "$@"
