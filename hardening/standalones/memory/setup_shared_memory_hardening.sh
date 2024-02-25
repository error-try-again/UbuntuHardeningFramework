#!/usr/bin/env bash

# This script secures the shared memory segment in Linux systems.
# It modifies /run/shm (or /dev/shm) mount options to 'noexec', 'nosuid', and 'nodev'.
# Ensures these options persist on reboot by updating /etc/fstab.
# Requires root privileges and creates a backup of /etc/fstab before modifications.

# Check if script is being run as root
check_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "Error: This script must be run as root. Please rerun as root or using sudo." >&2
    exit 1
  fi
}

# Creates a backup of /etc/fstab
backup_fstab() {
  echo "Backing up /etc/fstab..."
  cp /etc/fstab /etc/fstab.backup && echo "Backup created successfully." || {
    echo "Failed to create backup of /etc/fstab." >&2
    exit 1
  }
}

# Updates /etc/fstab with correct options for /run/shm
update_fstab() {
  local fstab_entry="$1"
  if grep -qE "^tmpfs /run/shm tmpfs" /etc/fstab; then
    echo "Shared memory already secured, checking options..."
    if ! grep -qE "^${fstab_entry}" /etc/fstab; then
      echo "Updating /etc/fstab with correct options..."
      sed -i "/^tmpfs \/run\/shm tmpfs/c\\${fstab_entry}" /etc/fstab && echo "Entry updated." || {
        echo "Failed to update fstab." >&2
        exit 1
      }
    else
      echo "Correct options already set."
    fi
  else
    echo "Adding new entry to /etc/fstab..."
    echo "${fstab_entry}" >> /etc/fstab && echo "Entry added successfully." || {
      echo "Failed to add entry to /etc/fstab." >&2
      exit 1
    }
  fi
}

# Remounts /run/shm with new options to take effect
remount_shm() {
  echo "Remounting /run/shm with new options..."
  if mount -o remount /run/shm; then
    echo "Remount successful."
  else
    echo "Remount failed. Please manually check mount options." >&2
    exit 1
  fi
}

# Validates that /run/shm is secured correctly
validate_secure_shared_memory() {
  local fstab_entry="$1"
  echo "Validating shared memory security..."

  if [[ ! -f /etc/fstab.backup ]]; then
    echo "Backup of /etc/fstab not found, validation cannot proceed." >&2
    exit 1
  fi

  if ! grep -qE "^${fstab_entry}" /etc/fstab; then
    echo "fstab entry incorrect or missing." >&2
    return 1
  fi

  local mount_options
  mount_options=$(mount | grep ' /run/shm ' | awk '{print $6}' | tr -d '()')
  local option
  for option in noexec nosuid nodev; do
    if [[ ${mount_options} != *"${option}"* ]]; then
      echo "/run/.shm does not have ${option} option set." >&2
      return 1
    fi
  done

  echo "Shared memory is secured correctly."
}

# Main function to set up shared memory hardening
setup_shared_memory_hardening() {
  fstab_entry="tmpfs /run/shm tmpfs defaults,noexec,nosuid,nodev 0 0"
  check_root
  backup_fstab
  update_fstab "${fstab_entry}"
  remount_shm
  validate_secure_shared_memory "${fstab_entry}"
}
