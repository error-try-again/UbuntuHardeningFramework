#!/usr/bin/env bash

set -euo pipefail

# Checks if the script is being run as root
check_root() {
  local uuid
  uuid=$(id -u)
  if [[ ${uuid} -ne 0 ]]; then
    echo "This script must be run as root. Exiting..." >&2
    exit 1
  fi
}

# This script hardens the network configuration to improve security. It includes
# backup of existing configurations, application of strict networking rules,
# and adjustments to system parameters to mitigate various network-based attacks.
harden_networking_stack_kernel_params() {
  echo "Starting network configuration hardening process..."

  # Create a backup of the existing sysctl configuration with a timestamp
  # to allow easy restoration if needed. The script exits if the backup fails.
  local backup_file
  backup_file="/etc/sysctl.conf.backup.$(date +%Y%m%d%H%M%S)"
  echo "Creating backup of current sysctl configuration..."
  cp /etc/sysctl.conf "${backup_file}" && echo "Backup saved as ${backup_file}" || { echo "Backup failed. Exiting."; exit 1; }

  # Specifies the file where hardening configurations will be written.
  # This approach keeps our custom configurations separate for easy management.
  local hardening_config="/etc/sysctl.d/99-hardening.conf"
  echo "Applying hardening configurations to ${hardening_config}..."

  {
    echo "# Custom hardening network settings"

    # Prevent IP spoofing by enabling reverse path filtering on all interfaces.
    echo "net.ipv4.conf.all.rp_filter=1"
    echo "net.ipv4.conf.default.rp_filter=1"

    # Disable IP forwarding to prevent the machine from routing packets.
    echo "net.ipv4.ip_forward=0"

    # Block source routed packets to prevent direct routing control.
    echo "net.ipv4.conf.all.accept_source_route=0"
    echo "net.ipv4.conf.default.accept_source_route=0"

    # Disable ICMP redirects to prevent misrouting and MITM attacks.
    echo "net.ipv4.conf.all.accept_redirects=0"
    echo "net.ipv4.conf.default.accept_redirects=0"

    echo "net.ipv4.conf.all.secure_redirects=1"
    echo "net.ipv4.conf.default.secure_redirects=1"

    # Mitigate smurf attacks by ignoring ICMP broadcasts.
    echo "net.ipv4.icmp_echo_ignore_broadcasts=1"

    # Protect against bogus ICMP responses which can lead to DOS attacks.
    echo "net.ipv4.icmp_ignore_bogus_error_responses=1"

    # Use TCP SYN cookies to protect against SYN flood attacks.
    echo "net.ipv4.tcp_syncookies=1"

    # Log packets with impossible source addresses to detect spoofing.
    echo "net.ipv4.conf.all.log_martians=1"
    echo "net.ipv4.conf.default.log_martians=1"

    # Disable sending of ICMP redirects to prevent potential misuse.
    echo "net.ipv4.conf.all.send_redirects=0"
    echo "net.ipv4.conf.default.send_redirects=0"

    # Adjust port and buffer settings to mitigate denial-of-service attacks.
    echo "net.ipv4.ip_local_port_range=1024 65535"
    echo "net.ipv4.tcp_fin_timeout=30"
    echo "net.ipv4.tcp_keepalive_time=300"
    echo "net.ipv4.tcp_keepalive_probes=5"
    echo "net.ipv4.tcp_keepalive_intvl=15"
    echo "net.ipv4.tcp_rmem=4096 87380 6291456"
    echo "net.ipv4.tcp_wmem=4096 16384 4194304"
    echo "net.ipv4.udp_rmem_min=16384"
    echo "net.ipv4.udp_wmem_min=16384"

    # Additional protections against TCP TIME-WAIT assassination and ARP spoofing.
    echo "net.ipv4.tcp_rfc1337=1"
    echo "net.ipv4.conf.all.drop_gratuitous_arp=1"

    # Limit SYN backlog and retries to mitigate SYN flood attacks.
    echo "net.ipv4.tcp_max_syn_backlog=2048"
    echo "net.ipv4.tcp_synack_retries=2"

    # IPv6 specific settings to disable redirects and autoconfiguration
    # if IPv6 is not used. This helps in simplifying network security posture.
    echo "net.ipv6.conf.all.accept_redirects=0"
    echo "net.ipv6.conf.default.accept_redirects=0"

    echo "net.ipv6.conf.all.disable_ipv6=1"
    echo "net.ipv6.conf.default.disable_ipv6=1"

    # Disable IPv6 features that may not be needed and could pose security risks.
    echo "net.ipv6.conf.all.accept_ra=0"
    echo "net.ipv6.conf.default.accept_ra=0"

    echo "net.ipv6.conf.all.proxy_ndp=0"
    echo "net.ipv6.conf.default.proxy_ndp=0"

  } > "${hardening_config}"

  # Apply the new sysctl parameters from the configuration file.
  echo "Applying sysctl parameters..."
  sysctl --system

  echo "Network configuration hardening completed."
}

# Main function
main() {
  check_root
  harden_networking_stack_kernel_params
}

main "$@"