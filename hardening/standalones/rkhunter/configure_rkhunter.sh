#!/usr/bin/env bash

# Configures rkhunter to run daily and email results
configure_rkhunter() {
    # Modify the UPDATE_MIRRORS and MIRRORS_MODE settings in /etc/rkhunter.conf to enable the use of mirrors
    sed -i -e 's|^[#]*[[:space:]]*UPDATE_MIRRORS=.*|UPDATE_MIRRORS=1|' /etc/rkhunter.conf
    sed -i -e 's|^[#]*[[:space:]]*MIRRORS_MODE=.*|MIRRORS_MODE=0|' /etc/rkhunter.conf

    # Modify the APPEND_LOG setting in /etc/rkhunter.conf to ensure that logs are appended rather than overwritten
    sed -i -e 's|^[#]*[[:space:]]*APPEND_LOG=.*|APPEND_LOG=1|' /etc/rkhunter.conf

    # Modify the USE_SYSLOG setting in /etc/rkhunter.conf to enable the use of syslog integration
    sed -i "s|^USE_SYSLOG=.*|USE_SYSLOG=authpriv.warning|" /etc/rkhunter.conf

    # Modify the WEB_CMD setting in /etc/rkhunter.conf to disable the use of the web command
    sed -i "s|^WEB_CMD=.*|WEB_CMD=|" /etc/rkhunter.conf

    # Use GLOBSTAR to improve comprehensive file pattern matching.
    # sed -i -e 's|^[#]*[[:space:]]*GLOBSTAR=.*|GLOBSTAR=1|' /etc/rkhunter.conf

    # Adjust ENABLE_TESTS and DISABLE_TESTS to enable all tests
    sed -i -e 's|^[#]*[[:space:]]*ENABLE_TESTS=.*|ENABLE_TESTS=ALL|' /etc/rkhunter.conf
    sed -i -e 's|^[#]*[[:space:]]*DISABLE_TESTS=.*|DISABLE_TESTS=None|' /etc/rkhunter.conf

    # set the default installer values so that
    echo "rkhunter rkhunter/apt_autogen boolean true" | debconf-set-selections
    echo "rkhunter rkhunter/cron_daily_run boolean true" | debconf-set-selections
    echo "rkhunter rkhunter/cron_db_update boolean true" | debconf-set-selections

    # use dpkg-reconfigure using debian standard packaging with non-interactive mode
    dpkg-reconfigure debconf -f noninteractive

    # Modify /etc/default/rkhunter to enable daily runs and database updates
    sed -i -e 's|^[#]*[[:space:]]*CRON_DAILY_RUN=.*|CRON_DAILY_RUN="true"|' /etc/default/rkhunter # enable daily runs
    sed -i -e 's|^[#]*[[:space:]]*CRON_DB_UPDATE=.*|CRON_DB_UPDATE="true"|' /etc/default/rkhunter # enable database updates
    sed -i -e 's|^[#]*[[:space:]]*REPORT_EMAIL=.*|REPORT_EMAIL=yane.karov@gmail.com|' /etc/default/rkhunter # set the email address to send reports to
    sed -i -e 's|^[#]*[[:space:]]*DB_UPDATE_EMAIL=.*|DB_UPDATE_EMAIL="true"|' /etc/default/rkhunter # enable database update emails
    sed -i -e 's|^[#]*[[:space:]]*APT_AUTOGEN=.*|APT_AUTOGEN="true"|' /etc/default/rkhunter # enable automatic updates

}
