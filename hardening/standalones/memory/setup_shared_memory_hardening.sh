#!/usr/bin/env bash

# Enhances the security of the shared memory filesystem by setting 'noexec', 'nosuid', and 'nodev' options.
# Ensures these settings persist after reboot by updating /etc/fstab, and requires root privileges.


# Check if script is being run as root
check_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "Error: This script must be run as root. Please rerun as root or using sudo." >&2
    exit 1
  fi
}

# Backs up the current fstab file with a timestamp
backup_fstab() {
  local timestamp
  timestamp=$(date +"%Y%m%d-%H%M%S")
  echo "Backing up /etc/fstab to /etc/fstab.backup.${timestamp}..."
  cp /etc/fstab "/etc/fstab.backup.${timestamp}" && echo "Backup created successfully." || {
    echo "Failed to create backup of /etc/fstab." >&2
    exit 2
  }
}

# Updates or adds the fstab entry for /run/shm with secure options
secure_fstab_entry() {
  local fstab_entry="$1"
  if grep -qE "^tmpfs /run/shm tmpfs" /etc/fstab; then
    echo "Shared memory entry exists, ensuring it has secure options..."
    if ! grep -qE "^${fstab_entry}" /etc/fstab; then
      echo "Updating /etc/fstab with secure options for shared memory..."
      sed -i "/^tmpfs \/run\/shm tmpfs/c\\${fstab_entry}" /etc/fstab && echo "fstab entry updated." || {
        echo "Failed to update fstab." >&2
        exit 3
      }
    else
      echo "Shared memory already has secure options."
    fi
  else
    echo "Adding secure shared memory entry to /etc/fstab..."
    echo "${fstab_entry}" >> /etc/fstab && echo "Entry added successfully." || {
      echo "Failed to add secure entry to /etc/fstab." >&2
      exit 4
    }
  fi
}

# Remounts /run/shm to apply new options
remount_shared_memory() {
  echo "Applying new options by remounting /run/shm..."
  if mount -o remount,defaults,noexec,nosuid,nodev /run/shm; then
    echo "Remount successful."
  else
    echo "Remount failed. Please manually check mount options." >&2
    exit 5
  fi
}

# Validates the security settings of /run/shm
validate_security_settings() {
  local fstab_entry="$1"
  echo "Validating the security settings of shared memory..."

  local mount_options
  mount_options=$(mount | grep ' /run/shm ' | awk '{print $6}' | tr -d '()')
  local required_options=("noexec" "nosuid" "nodev")
  local option
    for option in "${required_options[@]}"; do
    if [[ ${mount_options} != *"${option}"* ]]; then
      echo "/run/shm does not have the ${option} option set." >&2
      exit 6
    fi
  done

  echo "Shared memory security settings validated successfully."
}

main_shared_memory_hardening_setup() {
  local fstab_entry="tmpfs /run/shm tmpfs defaults,noexec,nosuid,nodev 0 0"
  ensure_root
  backup_fstab
  secure_fstab_entry "${fstab_entry}"
  remount_shared_memory
  validate_security_settings "${fstab_entry}"
}

