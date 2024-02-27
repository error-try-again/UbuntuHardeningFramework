#!/usr/bin/env bash

set -euo pipefail

# Main function
main() {
  check_root
  echo "Initializing rkhunter..."
  install_apt_packages "debconf-utils" "rkhunter"
  configure_rkhunter
  cp -r standalones/rkhunter/rkhunter_weekly.sh /etc/cron.weekly/rkhunter
  cp -r standalones/rkhunter/rkhunter_daily.sh /etc/cron.daily/rkhunter
}

main "$@"