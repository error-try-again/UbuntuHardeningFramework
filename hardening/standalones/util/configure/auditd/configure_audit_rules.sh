#!/usr/bin/env bash

# Configure Auditd rules
configure_audit_rules() {
  log "Configuring Auditd rules..."

  # Define custom audit rules
  cat << EOL > /etc/audit/rules.d/custom-audit-rules.rules
# Monitor system changes
-w /etc/passwd -p wa
-w /etc/shadow -p wa
-w /etc/sudoers -p wa
-w /etc/group -p wa

# Monitor login and authentication events
-w /var/log/auth.log -p wa
-w /var/log/secure -p wa

# Monitor executable files
-a always,exit -F arch=b64 -S execve
-a always,exit -F arch=b32 -S execve
EOL

  log "Custom Auditd rules configured."
}
