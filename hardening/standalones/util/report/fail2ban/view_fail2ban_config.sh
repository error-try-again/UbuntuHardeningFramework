#!/usr/bin/env bash

# View the first 40 lines of Fail2ban configuration file
view_fail2ban_config() {
    log "Viewing the first 40 lines of Fail2ban configuration..."
    head -n 40 /etc/fail2ban/jail.conf
}
