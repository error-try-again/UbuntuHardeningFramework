#!/usr/bin/env bash

# Helpers

# Checks if the script is being run as root (used for apt)
check_root() {
  if [[ ${EUID} -ne 0   ]]; then
    echo "Please run as root"
    exit 1
  fi
}

# Append or update a line in a file with a key value pair
write_key() {
    local key="$1"
    local value="$2"
    echo "${key} ${value}" >> "${config_file}"
}

# Automatic updates

# Installs apt packages
install_apt_packages() {
  apt install rkhunter debconf-utils unattended-upgrades -y
}

# Configures automatic updates
configure_auto_updates() {
  # Configure automatic updates
  config_file="/etc/apt/apt.conf.d/50unattended-upgrades"

  # Define the lines to insert
  declare -A updates=(
        ["Unattended-Upgrade::DevRelease"]='"auto";'
        ["Unattended-Upgrade::MinimalSteps"]='"true";'
        ["Unattended-Upgrade::Mail"]='"yane.neurogames@gmail.com";'
        ["Unattended-Upgrade::MailReport"]='"always";'
        ["Unattended-Upgrade::Remove-Unused-Kernel-Packages"]='"false";'
        ["Unattended-Upgrade::Automatic-Reboot-WithUsers"]='"true";'
        ["Unattended-Upgrade::Automatic-Reboot-Time"]='"00:00";'
        ["Acquire::http::Dl-Limit"]='"100";'
        ["Unattended-Upgrade::SyslogEnable"]='"true";'
        ["Unattended-Upgrade::SyslogFacility"]='"daemon";'
        ["Unattended-Upgrade::Verbose"]='"true";'
        ["Unattended-Upgrade::Debug"]='"true";'
        ["Unattended-Upgrade::AutoFixInterruptedDpkg"]='"true";'
  )

  echo "Backing up ${config_file}..."

  # Clear the contents of the file
  echo "" > "${config_file}"

  # Update each entry
  local key
  for key in "${!updates[@]}"; do
    echo "Updating ${key}..."
    write_key "${key}" "${updates[${key}]}"
  done

    # Add an Unattended-Upgrade::Allowed-Origins section
    cat << EOF | sudo tee -a "${config_file}" > /dev/null
Unattended-Upgrade::Allowed-Origins {
        "\${distro_id}:\${distro_codename}";
        "\${distro_id}:\${distro_codename}-security";
        "\${distro_id}ESMApps:\${distro_codename}-apps-security";
        "\${distro_id}ESM:\${distro_codename}-infra-security";
        "\${distro_id}:\${distro_codename}-updates";
};
EOF

  update_cron_job "/usr/bin/unattended-upgrade -d" "/var/log/unattended-upgrades.log"
}

# Cron

# Updates the cron job for a script
update_cron_job() {
  local script="$1"
  local log_file="$2"
  local cron_entry="0 0 * * * ${script} >${log_file} 2>&1"

  local current_cron_job
  current_cron_job=$(crontab -l | grep "${script}")

  if [[ -z ${current_cron_job} ]] || [[ ${current_cron_job} != "${cron_entry}" ]]; then
    (
      crontab -l 2> /dev/null | grep -v "${script}"
                                                         echo "${cron_entry}"
    )                                                                          | crontab -
    echo "Cron job updated."
  else
    echo "Cron job already up to date."
  fi
}

# RKHunter

# Fork of the default rkhunter weekly cron job
# This version still uses variables present in /etc/default/rkhunter and has been modified to send an email report
# if there are any warnings to report.
generate_rkhunter_weekly_cron() {
  cat << 'EOF' > /etc/cron.weekly/rkhunter
#!/usr/bin/env bash

#######################################
# Checks whether the script is run as root
# Globals:
#   EUID
# Arguments:
#  None
#######################################
check_for_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
  fi
}

#######################################
# Checks whether a command is executable
# Arguments:
#   1. command
#######################################
check_executability() {
  local command="$1"
  if ! [[ -x "$(command -v "${command}")" ]]; then
    log_message "Error: ${command} not found or not executable."
    exit 1
  fi
}

#######################################
# Create a file if it doesn't exist
# Arguments:
#   1
#######################################
create_file_if_not_exists() {
  local file="$1"
  if ! [[ -f ${file}   ]]; then
    touch "${file}"
    if ! [[ -f ${file}   ]]; then
      log_message "Error: Failed to create file ${file}."
      exit 1
    fi
  fi
}

#######################################
# Add a timestamp to the log message and print it to stdout and the log file
# Globals:
#   log_file
# Arguments:
#   1
#######################################
log_message() {
    local date
    date=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${date}] $1" | tee -a "${log_file}"
}

#######################################
# Send an email with the given subject and content to the given recipient
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
# Check for the presence of web tools required for downloading updates
# Arguments:
#  None
# Returns:
#   0 ...
#   1 ...
#######################################
check_for_web_tools() {
  local web_tools=(wget curl links elinks lynx)
  local tool
  for tool in "${web_tools[@]}"; do
    if [[ -x "$(command -v "${tool}")" ]]; then
      return 0
    fi
  done
  log_message "Error: No tool to download rkhunter updates was found. Please install wget, curl, (e)links or lynx."
  return 1
}

#######################################
# Handle rkhunter database updates
# Globals:
#   DB_UPDATE_EMAIL
# Arguments:
#   1
#   2
#######################################
handle_updates() {
  local rkhunter_path="$1"
  local recipient="$2"
  local report_file="$3"

  check_for_web_tools || exit 1

  if [[ ${DB_UPDATE_EMAIL} =~ [YyTt]   ]]; then
    log_message "Weekly rkhunter database update started"
    "${rkhunter_path}" --versioncheck --nocolors --appendlog > "${report_file}" 2>&1
    "${rkhunter_path}" --update --nocolors --appendlog > "${report_file}" 2>&1

    local report_content
    local hostname

    report_content=$(cat "${report_file}")
    hostname=$(hostname)

    local report_date
    report_date=$(date '+%Y-%m-%d')

    local subject
    subject="[rkhunter] - [${hostname}] - [Weekly Report] - [$(date '+%Y-%m-%d %H:%M')]"

    send_email "${subject}" "${report_content}" "${recipient}"
  else
    log_message "DB_UPDATE_EMAIL is not set to true. Exiting."
    exit 0
  fi
}

#######################################
# Main function
# Globals:
#   CRON_DB_UPDATE
#   log_file
# Arguments:
#  None
#######################################
main() {
  # Check if the script is run as root
  check_for_root

  # Source config
  . /etc/default/rkhunter

  log_file="/var/log/rkhunter.log"
  report_file="/tmp/rkhunter_weekly_report.log"

  local rkhunter_path
  rkhunter_path=$(command -v rkhunter)

  # Check if rkhunter is installed and executable
  check_executability "${rkhunter_path}"
  check_executability "sendmail"

  create_file_if_not_exists "${log_file}"
  create_file_if_not_exists "${report_file}"

  # Run handle_updates if configured to do so in cron
  [[ ${CRON_DB_UPDATE} =~ [YyTt] ]] && handle_updates "${rkhunter_path}" "${REPORT_EMAIL}" "${report_file}"
}

main "$@"

EOF
}

#######################################
# Fork of the default rkhunter daily cron job
# This version still uses variables present in /etc/default/rkhunter and has been modified to send an email report
# if there are any warnings to report.
# Arguments:
#  None
#######################################
generate_rkhunter_daily_cron() {
  cat << 'EOF' > /etc/cron.daily/rkhunter
#!/usr/bin/env bash

#######################################
# Checks whether the script is run as root
# Globals:
#   EUID
# Arguments:
#  None
#######################################
check_for_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
  fi
}

#######################################
# Checks whether a command is executable
# Arguments:
#   1. command
#######################################
check_executability() {
  local command="$1"
  if ! [[ -x "$(command -v "${command}")" ]]; then
    log_message "Error: ${command} not found or not executable."
    exit 1
  fi
}

#######################################
# Create a file if it doesn't exist
# Arguments:
#   1
#######################################
create_file_if_not_exists() {
  local file="$1"
  if ! [[ -f ${file}   ]]; then
    touch "${file}"
    if ! [[ -f ${file}   ]]; then
      log_message "Error: Failed to create file ${file}."
      exit 1
    fi
  fi
}

#######################################
# Add a timestamp to the log message and print it to stdout and the log file
# Globals:
#   LOG_FILE
# Arguments:
#   1
#######################################
log_message() {
    local date
    date=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${date}] $1" | tee -a "${log_file}"
}

#######################################
# Send an email with the given subject and content to the given recipient
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
# Handle the daily rkhunter run and send an email if there are warnings
# Globals:
#   CRON_DAILY_RUN
# Arguments:
#   1
#   2
#######################################
handle_updates() {
  local rkhunter_path="$1"
  local recipient="$2"
  local report_file="$3"

  # Set default nice value if not set
  local nice=${nice:-0}

  # Check if CRON_DAILY_RUN is set and proceed if it's true
  if [[ ${CRON_DAILY_RUN} =~ [YyTt]* ]]; then
    log_message "Starting rkhunter daily run..."
    /usr/bin/nice -n "${nice}" "${rkhunter_path}" --cronjob --report-warnings-only --appendlog > "${report_file}" 2>&1

    local report_content
    local hostname

    report_content=$(cat "${report_file}")
    hostname=$(hostname)

    local report_date
    report_date=$(date '+%Y-%m-%d')

    local subject
    subject="[rkhunter] - [${hostname}] - [Daily Report] - [$(date '+%Y-%m-%d %H:%M')]"

    send_email "${subject}" "${report_content}" "${recipient}"
    log_message "Daily report email sent."
  else
    log_message "CRON_DAILY_RUN is not set to true. Exiting."
    exit 0
  fi
}

#######################################
# Main function
# Globals:
#   log_file
# Arguments:
#  None
#######################################
main() {
  # Check if the script is run as root
  check_for_root

  # Source config
  . /etc/default/rkhunter

  log_file="/var/log/rkhunter.log"
  report_file="/tmp/rkhunter_report.log"

  local rkhunter_path
  rkhunter_path=$(command -v rkhunter)

  # Check if rkhunter is installed and executable
  check_executability "${rkhunter_path}"
  check_executability "sendmail"

  create_file_if_not_exists "${log_file}"
  create_file_if_not_exists "${report_file}"

  # Handle the daily rkhunter run
  handle_updates "${rkhunter_path}" "${REPORT_EMAIL}" "${report_file}"
}

main "$@"
EOF

}

# Runs rkhunter - checks for rootkits, backdoors and local exploits
# First updates the rkhunter database
# Then runs rkhunter with all tests enabled and only reports warnings
run_rkhunter() {
  echo "Running rkhunter update..."
  rkhunter --update --sk --enable all --disable none
  rkhunter --versioncheck --sk --enable all --disable none
  echo "Running rkhunter check..."
  rkhunter --config-check --sk --enable all --disable none
  rkhunter --checkall --sk --report-warnings-only
}

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
    sed -i -e 's|^[#]*[[:space:]]*CRON_DAILY_RUN=.*|CRON_DAILY_RUN="true"|' /etc/default/rkhunter
    sed -i -e 's|^[#]*[[:space:]]*CRON_DB_UPDATE=.*|CRON_DB_UPDATE="true"|' /etc/default/rkhunter
    sed -i -e 's|^[#]*[[:space:]]*REPORT_EMAIL=.*|REPORT_EMAIL=yane.neurogames@gmail.com|' /etc/default/rkhunter
    sed -i -e 's|^[#]*[[:space:]]*DB_UPDATE_EMAIL=.*|DB_UPDATE_EMAIL="true"|' /etc/default/rkhunter
    sed -i -e 's|^[#]*[[:space:]]*APT_AUTOGEN=.*|APT_AUTOGEN="true"|' /etc/default/rkhunter # enable automatic updates

}

# Lynis

# Generate the installer script to install Lynis from the official tarball and verify the GPG signature
configure_lynis_installer() {
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

EOF

    chmod 700 "${installer_location}"

    # Source the newly created installer script
    # shellcheck source=./${installer_location}
    . "${installer_location}"
}

# Fail2Ban

# Main
main() {
  check_root

  # Automatic updates
  install_apt_packages
  configure_auto_updates

  # RKHunter
  configure_rkhunter
  generate_rkhunter_weekly_cron
  generate_rkhunter_daily_cron

  # Lynis
  local lynis_script_path="/usr/local/bin/lynis_installer.sh"
  configure_lynis_installer "${lynis_script_path}"
  update_cron_job "${lynis_script_path}" "/var/log/lynis_cron.log"
}

main "$@"
