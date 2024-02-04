#!/usr/bin/env bash

# Validate that the script is being run as root
validate_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
  fi
}

# Updates the cron job for a script
update_cron_job() {
  local script="$1"
  local log_file="$2"
  local cron_entry="0 0 * * * ${script} >${log_file} 2>&1"

  local current_cron_job
  current_cron_job=$(crontab -l | grep "${script}")

  if [[ -z ${current_cron_job}   ]] || [[ ${current_cron_job} != "${cron_entry}"   ]]; then
    (
      crontab -l 2> /dev/null | grep -v "${script}"
                                                         echo "${cron_entry}"
    )                                                                          | crontab -
    echo "Cron job updated."
  else
    echo "Cron job already up to date."
  fi
}

# Generate the installer script to install Lynis from the official tarball and verify the GPG signature
create_installer() {
  local installer_location="$1"

  cat << 'EOF' > "${installer_location}"
#!/usr/bin/env bash

# Cleans up old versions of Lynis
cleanup_old_lynis() {
  local lynis_dir="$1"
  local lynis_version="$2"
  echo "Cleaning up old versions of Lynis..."
  find "${lynis_dir}" -maxdepth 1 -type d -name 'lynis-*' -not -name "lynis-${lynis_version}" -exec rm -rf {} \;
  [[ -d "${lynis_dir}/.git" ]] && echo "Removing existing Lynis Git installation..." && rm -rf "${lynis_dir}"
}

# Creates the Lynis directory
create_directory() {
  local lynis_dir="$1"
  echo "Creating Lynis directory..."
  mkdir -p "${lynis_dir}"
}

# Downloads the Lynis tarball and signature file
download_lynis() {
  local lynis_tarball="$1"
  local lynis_tarball_url="$2"
  local download_path="$3"
  echo "Downloading Lynis version..."

  echo "Downloading Lynis version ${lynis_version}..."
  wget -q "${lynis_tarball_url}" -O "${download_path}/${lynis_tarball}" || {
                                                                             echo "Failed to download Lynis tarball"
                                                                                                                      exit 1
  }
  wget -q "${lynis_tarball_url}.asc" -O "${download_path}/${lynis_tarball}.asc" || {
                                                                                     echo "Failed to download Lynis signature file"
                                                                                                                                     exit 1
  }
  [[ -s "${download_path}/${lynis_tarball}.asc" ]] || {
                                                      echo "Lynis signature file is missing or empty"
                                                                                                       exit 1
  }
}

# Unpacks the Lynis tarball
unpack_tarball() {
  local lynis_tarball="$1"
  local lynis_dir="$2"
  echo "Unpacking Lynis tarball..."
  tar xfvz "${lynis_tarball}" -C "${lynis_dir}" || {
                                                     echo "Failed to unpack Lynis tarball"
                                                                                            exit 1
  }
  echo "Contents of ${lynis_dir}:"
  ls -la "${lynis_dir}"
}

# Verifies the downloaded Lynis tarball against the checksum
verify_download() {
  local lynis_tarball="$1"
  echo "Verifying Lynis tarball..."
  sha256sum "${lynis_tarball}" || {
                                    echo "sha256sum checksum verification failed"
                                                                                   exit 1
  }
}

# Imports the GPG key used to sign the Lynis tarball and checks the fingerprint
import_and_retrieve_gpg_key_fingerprint() {
  local lynis_gpg_key_url="$1"
  wget "${lynis_gpg_key_url}" -O cisofy-software.pub || {
                                                          echo "Failed to download GPG key"
                                                                                             exit 1
  }
  gpg --import cisofy-software.pub || {
                                        echo "Failed to import GPG key"
                                                                         exit 1
  }

  local fingerprint
  fingerprint=$(gpg --list-keys --with-fingerprint | grep -oP '([A-F0-9]{4}\s*){10}' | tail -1 | tr -d '[:space:]')

  echo "${fingerprint}"
}

# Verifies the signature of the Lynis tarball
verify_signature() {
  local lynis_tarball="$1"
  local lynis_tarball_signature="$2"
  gpg --verify "${lynis_tarball_signature}" "${lynis_tarball}" || {
                                                                    echo "GPG signature verification failed"
                                                                                                              exit 1
  }
  echo "GPG signature verified successfully."
}

# Compares the GPG key fingerprint with the DNS TXT record
compare_fingerprint_with_dns() {
  local expected_fingerprint="$1"

  local dns_fingerprint
  dns_fingerprint=$(host -t txt cisofy-software-key.cisofy.com | grep -oP 'Key fingerprint = \K.*' | tr -d '[:space:]' | tr -d '"')

  [[ ${dns_fingerprint} == "${expected_fingerprint}"  ]] || {
                                                            echo "DNS fingerprint mismatch"
                                                                                             exit 1
  }
  echo "DNS fingerprint verification successful."
}

# Sets the trust level of the GPG key
set_gpg_key_trust() {
  echo -e "5\ny\n" | gpg --command-fd 0 --edit-key "CISOfy software signing" trust
}

#######################################
# Links the Lynis binary to /usr/local/bin
# Arguments:
#   1
#######################################
link_lynis_tar_binary() {
  local lynis_dir="$1"
  echo "Linking Lynis binary..."

  # Remove the old symlink if it exists and create a new one
  if [[ -f /usr/local/bin/lynis ]]; then
    unlink /usr/local/bin/lynis
    ln -s "${lynis_dir}/lynis/lynis" /usr/local/bin/lynis
  else
    ln -s "${lynis_dir}/lynis/lynis" /usr/local/bin/lynis
  fi

}

#######################################
# Add a timestamp to the log message and print it to stdout and the log file
# Globals:
#   None
# Arguments:
#   1
#######################################
log_message() {
    local log_file="/var/log/lynis.log"
    local date
    date=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${date}] $1" | tee -a "${log_file}"
}

#######################################
# Sends an email
# Arguments:
#   1
#   2
#   3
# Returns:
#   1 ...
#######################################
send_email() {
  local subject="$1"
  local content="$2"
  local recipient="$3"

  local mail_tool="sendmail"

  local hostname
  hostname=$(hostname)

  subject="[$1] - [${hostname}] - $(date '+%Y-%m-%d %H:%M')"

  local content
  content=$(cat "$2")

  if [[ -z ${recipient} ]]; then
    log_message "Error: Email recipient not specified."
    return 1
  fi

  if ! echo -e "Subject: ${subject}\nTo: ${recipient}\nFrom: ${recipient}\n\n${content}" | ${mail_tool} -f "${recipient}" -t "${recipient}"; then
    log_message "Error: Failed to send email."
  else
    log_message "Email sent: ${subject}"
  fi
}

#######################################
# Controls script flow for installing Lynis
# Arguments:
#  None
#######################################
lynis_installer() {
  local lynis_version="3.0.9"
  local lynis_dir="/usr/local"
  local log_dir="/var/log"
  local lynis_tarball_url="https://downloads.cisofy.com/lynis/lynis-3.0.9.tar.gz"
  local lynis_gpg_key_url="https://cisofy.com/files/cisofy-software.pub"

  cd "${lynis_dir}" || {
                        echo "Failed to change directory to ${lynis_dir}"
                                                                 exit 1
  }

  cleanup_old_lynis "${lynis_dir}" "${lynis_version}"
  create_directory "${lynis_dir}"
  download_lynis "lynis-${lynis_version}.tar.gz" "${lynis_tarball_url}" "${lynis_dir}"
  unpack_tarball "lynis-${lynis_version}.tar.gz" "${lynis_dir}"
  verify_download "${lynis_dir}/lynis-${lynis_version}.tar.gz"

  local fingerprint
  fingerprint=$(import_and_retrieve_gpg_key_fingerprint "${lynis_gpg_key_url}")

  verify_signature "${lynis_dir}/lynis-${lynis_version}.tar.gz" "${lynis_dir}/lynis-${lynis_version}.tar.gz.asc"
  compare_fingerprint_with_dns "${fingerprint}"
  set_gpg_key_trust
  link_lynis_tar_binary "${lynis_dir}"

  # Ensure the Lynis script is r/w/x by root only
  local lynis_executable_path="${lynis_dir}/lynis/lynis"
  chown root:root "${lynis_executable_path}"
  chmod 700 "${lynis_executable_path}"

  # Ensure the Lynis script is executable
  if [[ ! -x ${lynis_executable_path}   ]]; then
    echo "Lynis script is not executable"
    exit 1
  fi

  echo "Executing the Lynis script..."
  cd "${lynis_dir}/lynis" && ls -la

  ./lynis show version

  # Run the Lynis audit and pentest
  ./lynis audit system --quiet
  #  ./lynis --pentest --quiet
  #  ./lynis --forensics --quiet
  #  ./lynis --devops --quiet
  #  ./lynis --developer --quiet

  # Send the audit report via email
  send_email "Lynis Audit Report" "${log_dir}/lynis-report.dat" "yane.neurogames@gmail.com"
}

#######################################
# Main function to control script flow
# Arguments:
#  None
#######################################
main() {
  lynis_installer
}

main
EOF

  chmod 700 "${installer_location}"

  # Source the newly created installer script
  # shellcheck source=./${installer_location}
  . "${installer_location}"
}

# Main function to control script flow
main() {
  validate_root

  local lynis_script_path="/usr/local/bin/lynis_installer.sh"

  # Dynamically generate the installer
  create_installer "${lynis_script_path}"

  # Update the cron job
  update_cron_job "${lynis_script_path}" "/var/log/lynis_cron.log"
}

main "$@"
