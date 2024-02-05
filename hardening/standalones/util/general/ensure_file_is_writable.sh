#!/usr/bin/env bash

# Ensure that a file is writeable
ensure_file_is_writable() {
  local file="$1"
  local error_log_file="$2"
  if [[ ! -w ${file} ]]; then
    system_log "ERROR" "File is not writable: ${file}" "${error_log_file}"
    exit 1
  fi
}
