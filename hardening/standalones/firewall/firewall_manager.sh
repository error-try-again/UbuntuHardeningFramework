#!/usr/bin/env bash

# Firewall Backup and Restore Manager
# Supports iptables, ip6tables, and UFW.

# Logging function
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a firewall_manager.log
}

# Check if script is run as root
check_root() {
  if [[ ${EUID} -ne 0 ]]; then
    log_message "This script requires root privileges."
    return 1
  fi
}

# Prompt for confirmation
prompt_confirmation() {
  while true; do
    local response
    read -p "$1 (y/N): " response
    case "${response}" in
      [yY][eE][sS] | [yY]) return 0 ;;
      [nN][oO] | [nN] | "")
        log_message "Operation cancelled."
        return 1
        ;;
      *) echo "Please answer 'yes' or 'no'." ;;
    esac
  done
}

# Check for iptables, ip6tables, and UFW availability
check_requirements() {
  local cmd
  for cmd in iptables ip6tables ufw; do
    if ! command -v "${cmd}" &> /dev/null; then
      log_message "${cmd} is not installed but required."
      return 1
    fi
  done
}

# Setup default deny firewall rules
setup_default_deny_firewall() {
  local firewall_type="$1"
  case ${firewall_type} in
    iptables)
      iptables -P INPUT DROP
      iptables -P FORWARD DROP
      iptables -P OUTPUT ACCEPT
      iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      iptables -A INPUT -i lo -j ACCEPT
      log_message "Default deny firewall rules set for iptables."
      ;;
    ip6tables)
      ip6tables -P INPUT DROP
      ip6tables -P FORWARD DROP
      ip6tables -P OUTPUT ACCEPT
      ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      ip6tables -A INPUT -i lo -j ACCEPT
      log_message "Default deny firewall rules set for ip6tables."
      ;;
    ufw)
      ufw default deny incoming
      ufw default allow outgoing
      log_message "Default deny firewall rules set for UFW."
      ;;
    *)
      log_message "Unsupported firewall type for default deny setup: ${firewall_type}."
      return 1
      ;;
  esac
}

# Backup UFW rules
backup_ufw_rules() {
  local backup_dir="$1"
  mkdir -p "${backup_dir}" || {
    log_message "Failed to create backup directory."
    return 1
  }

  if ! ufw status verbose | grep -q "Status: active"; then
    log_message "UFW is not active. Please run 'ufw enable' and configure rules before backing up."
    return 1
  fi

  # Explicitly list all files without using brace expansion
  local paths=(
    /etc/ufw/before.rules
    /etc/ufw/before6.rules
    /etc/ufw/after.rules
    /etc/ufw/after6.rules
    /etc/ufw/user.rules
    /etc/ufw/user6.rules
    /etc/ufw/ufw.conf
    /etc/ufw/sysctl.conf
  )

  for path in "${paths[@]}"; do
    if [[ -e ${path} ]]; then
      log_message "Backing up: ${path}."
      if [[ ${path} != "${backup_dir}/$(basename "${path}")" ]]; then
        cp -R "${path}" "${backup_dir}/" || {
          log_message "Failed to backup ${path}."
          return 1
        }
      else
        log_message "Skipping: ${path}. Destination same as source."
      fi
    else
      log_message "Missing: ${path}."
    fi
  done

  # Handle the applications.d directory
  if [[ -d /etc/ufw/applications.d ]]; then
    cp -R /etc/ufw/applications.d "${backup_dir}" || {
      log_message "Failed to backup /etc/ufw/applications.d."
      return 1
    }
  else
    log_message "Missing: /etc/ufw/applications.d."
  fi

  log_message "Note: Certain files such as /etc/ufw/user.rules and /etc/ufw/user6.rules are automatically generated and will not be reflected on restore. Any changes should be made to /etc/ufw/[after.init, before.init, ufw.conf, user.rules] respectively."
  log_message "UFW rules backed up."
}

# Restore UFW rules
restore_ufw_rules() {
  local backup_dir="$1"
  if [[ ! -d ${backup_dir} ]]; then
    log_message "Backup directory missing."
    return 1
  fi

  # Explicitly list all files without using brace expansion
  local paths=(
    /etc/ufw/before.rules
    /etc/ufw/before6.rules
    /etc/ufw/after.rules
    /etc/ufw/after6.rules
    /etc/ufw/user.rules
    /etc/ufw/user6.rules
    /etc/ufw/ufw.conf
    /etc/ufw/sysctl.conf
  )

  for path in "${paths[@]}"; do
    local filename
    filename=$(basename "${path}")
    if [[ -e "${backup_dir}/${filename}" ]]; then
      log_message "Restoring: ${path}."
      cp -R "${backup_dir}/${filename}" "${path}" || {
        log_message "Failed to restore ${path}."
        return 1
      }
    else
      log_message "Missing in backup: ${filename}."
    fi
  done

  # Handle the applications.d directory
  if [[ -d "${backup_dir}/applications.d" ]]; then
    cp -R "${backup_dir}/applications.d" /etc/ufw/ || {
      log_message "Failed to restore /etc/ufw/applications.d."
      return 1
    }
  else
    log_message "Missing in backup: /etc/ufw/applications.d."
  fi

  log_message "Note: Certain files such as /etc/ufw/user.rules and /etc/ufw/user6.rules are automatically generated and will not be reflected on restore. Any changes should be made to /etc/ufw/[after.init, before.init, ufw.conf, user.rules] respectively."
  ufw reload && log_message "UFW rules restored."
}

# Backup iptables and ip6tables rules
backup_firewall_rules() {
  iptables-save > "$1" && log_message "iptables rules backed up to $1."
  ip6tables-save > "$2" && log_message "ip6tables rules backed up to $2."
}

# Restore iptables and ip6tables rules
restore_firewall_rules() {
  iptables-restore < "$1" && log_message "iptables rules restored from $1."
  ip6tables-restore < "$2" && log_message "ip6tables rules restored from $2."
}

# Main function
main() {
  if check_root; then
    if [[ $# -lt 2 ]]; then
      log_message "Usage: $0 [iptables|ufw] [backup|restore|default-deny] [backup_directory (optional for default-deny)]"
      exit 1
    fi
    local firewall_type=$1 action=$2 backup_dir=$3

    if check_requirements; then
      case ${action} in
        backup | restore)
          if [[ -z "${backup_dir}" ]]; then
            log_message "Backup directory is required for backup and restore actions."
            exit 1
          fi
          local backup_action="backup_${firewall_type}_rules" restore_action="restore_${firewall_type}_rules"
          if [[ ${action} == "backup" ]]; then
            ${backup_action} "${backup_dir}"
          elif [[ ${action} == "restore" ]]; then
            if prompt_confirmation "Confirm restoration of ${firewall_type} rules. This cannot be undone."; then
              ${restore_action} "${backup_dir}"
            fi
          fi
          ;;
        default-deny)
          if [[ -n "${backup_dir}" ]]; then
            log_message "Note: Backup directory argument is ignored for default-deny action."
          fi
          if prompt_confirmation "Set up a default deny firewall configuration?"; then
            setup_default_deny_firewall "${firewall_type}"
          fi
          ;;
        *)
          log_message "Invalid action: ${action}."
          exit 1
          ;;
      esac
    else
      exit 1
    fi
  else
    exit 1
  fi
}

main "$@"
