#!/usr/bin/env bash

# User mappings for SSH public keys
# Format: "UserName:Algorithm Public_Key Comment"
# Example A: "admin:ssh-rsa AAAAB3NzwnBnmkSBpiBsqQ== void@null"
allowed_ssh_pk_user_mappings="admin:ssh-rsa AAAAB3NzwnBnmkSBpiBsqQ== void@null
void:ssh-rsa AAAAB3NzwnBnmkSBpiBsqQ== void@null,ssh-ed2551 AAIDk7VFe example.eg@example.com"

# Users allowed to login via SSH
# Format: "user1,user2"
# Example A: "admin"
# Example B: "admin,void"
allowed_ssh_users="admin,void"

# IP Whitelist for Fail2Ban
# Format: "IP/CIDR"
# Example A: "1.1.1.1/32"
# Example B: "1.1.1.1/32,2.2.2.2/32"
ip_whitelist="1.1.1.1/32,2.2.2.2/32"

# Email settings for sending notifications
# Sender format: "<email>@<domain>"
# Example: "example@domain.com"
# Recipients format: "<email>@<domain>,<email>@<domain>"
# Example A: "example@domain.com"
# Example B: "example@domain.com,example1@domain.com"
sender="void@ex.com.au"
recipients="void.recip@ex.com,example1@domain.com"

# SSH Port for UFW and SSHD
ssh_port=2783

# Port list - used for mass allow or mass deny
# Format: "port1,port2"
# Example A: "22"
# Example B: "22,2222"
port_list_csv="8081,8080,443,80"

# Port Action - used for mass allow or mass deny
# Format: "allow" or "deny"
# Example A: "allow"
# Example B: "deny"
firewall_action="allow"

export allowed_ssh_pk_user_mappings allowed_ssh_users ip_whitelist sender recipients ssh_port port_list_csv firewall_action
