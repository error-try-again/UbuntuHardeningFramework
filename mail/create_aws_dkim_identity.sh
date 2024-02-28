#!/usr/bin/env bash

set -euo pipefail

# Create a new email identity in AWS SES with DKIM signing enabled using the AWS CLI
main() {

  # Generate a default private key using
  openssl genrsa -f4 -out private.key 2048

  # Set the domain, private key file, selector, and JSON file path for the AWS CLI command
  local domain="myawesomedomain.com.au"
  local private_key_file="private.key"
  local selector="selector1"
  local json_file_path="create-identity.json"

  # Read and clean the private key
  # Remove BEGIN/END lines, line breaks, and ensure it's base64-encoded without line breaks
  local cleaned_private_key
  cleaned_private_key=$(sed '1d;$d' "${private_key_file}" | tr -d '\n')

  # Create the JSON payload
  cat > "${json_file_path}" << EOF
{
    "EmailIdentity": "${domain}",
    "DkimSigningAttributes": {
        "DomainSigningPrivateKey": "${cleaned_private_key}",
        "DomainSigningSelector": "${selector}"
    }
}
EOF

  # Execute the AWS CLI command to create the email identity
  aws sesv2 create-email-identity --cli-input-json file://"${json_file_path}"
}

main "$@"
