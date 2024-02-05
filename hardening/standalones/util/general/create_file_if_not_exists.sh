#!/usr/bin/env bash

# Ensure that a file exists
create_file_if_not_exists() {
  local file="$1"
  local error_log_file="$2"
  if [[ ! -f ${file} ]]; then
    touch "${file}" || {
      system_log "ERROR" "Unable to create file: ${file}" "${error_log_file}"
      exit 1
    }
  fi
}
