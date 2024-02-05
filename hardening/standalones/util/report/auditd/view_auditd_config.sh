#!/usr/bin/env bash

# View Auditd configuration
view_auditd_config() {
  log "Viewing Auditd configuration..."
  auditctl -l

  log "Viewing Auditd rules..."
  cat /etc/audit/rules.d/custom-audit-rules.rules

  log "Viewing Auditd configuration..."
  cat /etc/audit/auditd.conf
}
