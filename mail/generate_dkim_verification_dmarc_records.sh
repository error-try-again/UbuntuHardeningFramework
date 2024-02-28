#!/usr/bin/env bash

# Cleans the key by removing the first and last lines and all newline characters
clean_key() {
  local key_file=$1
  local cleaned_key_file="${key_file}.cleaned"
  echo "Cleaning the key..."
  sed '1d;$d' "${key_file}" | tr -d '\n' > "${cleaned_key_file}"
  echo "Cleaned key saved to ${cleaned_key_file}"
}

# Generate RSA private key with a specified size and format (PKCS#1 or PKCS#8)
generate_private_key() {
  local file=$1
  local size=$2
  local format=$3
  echo "Generating RSA private key of size ${size} bits in ${format} format..."
  if [[ ${format} == "pkcs8"  ]]; then
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:"$size" -outform PEM -out "${file}.pem"
  else  # Default to PKCS #1 if not specified or specified as pkcs1
    openssl genrsa -out "${file}.pem" "${size}"
  fi
  clean_key "${file}.pem"
}

# Generate the corresponding public key from a private key
generate_public_key() {
  local private_key_file=$1
  local public_key_file=$2
  echo "Generating the public key from the private key..."
  openssl rsa -in "${private_key_file}" -outform PEM -pubout -out "${public_key_file}"
  clean_key "${public_key_file}"
}

# Prepare the public key for DNS TXT record inclusion by removing headers and concatenating lines
format_public_key_for_dns() {
  local public_key_file=$1
  local pubkey
  pubkey=$(grep -v -- "----" "${public_key_file}" | tr -d '\n')
  echo "\"v=DKIM1; k=rsa; p=${pubkey}\""
}

# Prepare the DMARC record for DNS TXT record inclusion
format_dmarc_record_for_dns() {
  local domain=$1

  # DMARC record with quarantine policy, including both aggregate and forensic reporting.
  # Provides options for SPF and DKIM alignment modes, and specifies the failure reporting condition.
  # Note: Adjust the 'pct' value to increase or decrease the percentage of messages subjected to the 'quarantine' policy based on your monitoring results and comfort level.
  # The 'fo=1' option means forensic reports are generated for any failures, providing detailed insights into issues.
  # 'adkim=r' and 'aspf=r' set relaxed alignment for DKIM and SPF, reducing false positives without significantly compromising security.
  echo "v=DMARC1; p=quarantine; pct=25; rua=mailto:dmarcreports@${domain}; ruf=mailto:forensic@${domain}; fo=1; adkim=r; aspf=r; rf=afrf"
}

# Output the DNS TXT record in a user-friendly format
output_dns_record() {
  local selector=$1
  local domain=$2
  local dkim_record_value=$3
  local dmarc_record_value=$4

  echo "########################################################"
  echo "Enter the following DNS record with your DNS provider:"
  echo "########################################################"
  echo "DKIM RECORD:"
  echo "Type: TXT"
  echo "Domain: ${selector}._domainkey.${domain}"
  echo "Value: ${dkim_record_value}"
  echo "TTL: 86400 (1 day recommended)"
  echo "########################################################"
  echo "DMARC RECORD:"
  echo "Type: TXT"
  echo "Domain: _dmarc.${domain}"
  echo "Value: ${dmarc_record_value}"
  echo "########################################################"
}

# Main function to orchestrate key generation and formatting for DNS
main() {
  local domain="example.com.au"
  local selector="selector1"
  local key_size=${1:-2048}  # Default to 2048 bits, can be overridden with script argument
  local key_format=${2:-pkcs1}  # Default to PKCS #1, can be overridden with script argument

  # Validate key size
  if [[ ${key_size} -lt 2048 ]]; then
    echo "For enhanced security, a key size of 2048 bits or higher is recommended."
    exit 1
  fi

  local private_key_file="${domain}.${selector}.private"
  local public_key_file="${private_key_file}.public.pem"

  # Generate private and public keys
  generate_private_key "${private_key_file}" "${key_size}" "${key_format}"
  generate_public_key "${private_key_file}.pem" "${public_key_file}"

  # Format the public key and DMARC record for DNS
  local dkim_record_value dmarc_record_value
  dkim_record_value=$(format_public_key_for_dns "${public_key_file}.cleaned")
  dmarc_record_value=$(format_dmarc_record_for_dns "${domain}")
  output_dns_record "${selector}" "${domain}" "${dkim_record_value}" "${dmarc_record_value}"
}

# Run the main function with all provided arguments
main "$@"
