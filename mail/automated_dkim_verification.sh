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
  if [[ "${format}" = "pkcs8" ]]; then
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

# Output the DNS TXT record in a user-friendly format
output_dns_record() {
  local selector=$1
  local domain=$2
  local dns_record_value=$3

  echo "########################################################"
  echo "Enter the following DNS record with your DNS provider:"
  echo "########################################################"
  echo "Type: TXT"
  echo "Domain: ${selector}._domainkey.${domain}"
  echo "Value: ${dns_record_value}"
  echo "TTL: 86400 (1 day recommended)"
  echo "########################################################"
}

# Main function to orchestrate key generation and formatting for DNS
main() {
  local domain="legendland.com.au"
  local selector="selector1"
  local key_size=${1:-2048}  # Default to 2048 bits, can be overridden with script argument
  local key_format=${2:-pkcs1}  # Default to PKCS #1, can be overridden with script argument

  # Validate key size
  if [[ ${key_size} -lt 1024 || ${key_size} -gt 2048     ]]; then
    echo "Key size must be between 1024 and 2048 bits."
    exit 1
  fi

  local private_key_file="${domain}.${selector}.private"
  local public_key_file="${private_key_file}.public.pem"

  # Generate private and public keys
  generate_private_key "${private_key_file}" "${key_size}" "${key_format}"
  generate_public_key "${private_key_file}.pem" "${public_key_file}"

  # Format public key and output DNS record
  local dns_record_value
  dns_record_value=$(format_public_key_for_dns "${public_key_file}.cleaned")
  output_dns_record "${selector}" "${domain}" "${dns_record_value}"
}

# Run the main function with all provided arguments
main "$@"
