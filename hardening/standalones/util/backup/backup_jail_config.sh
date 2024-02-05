#!/usr/bin/env bash

# Backup the existing Fail2ban jail configuration
backup_jail_config() {
  local backup_dir="/etc/fail2ban/backup"
  local current_config="/etc/fail2ban/jail.local"
  local timestamp
  timestamp=$(date +"%Y%m%d%H%M%S")

  log "Creating a backup of Fail2ban jail configuration..."

  # Create the backup directory if it doesn't exist
  mkdir -p "${backup_dir}"

  # Copy the current jail configuration to the backup directory
  cp "${current_config}" "${backup_dir}/jail.local_${timestamp}.bak" || {
    log "Failed to create a backup of Fail2ban jail configuration."
    exit 1
  } && {
    log "Backup of Fail2ban jail configuration created."
  }
}
