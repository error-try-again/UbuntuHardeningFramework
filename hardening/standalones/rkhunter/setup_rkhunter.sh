#!/usr/bin/env bash

# Main function
main_rkhunter_setup() {
  check_root
  echo "Initializing rkhunter..."
  install_apt_packages "debconf-utils" "rkhunter"
  configure_rkhunter
  cp -r standalones/rkhunter/rkhunter_weekly.sh /etc/cron.weekly/rkhunter
  cp -r standalones/rkhunter/rkhunter_daily.sh /etc/cron.daily/rkhunter
}
