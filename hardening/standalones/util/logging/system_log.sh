#!/usr/bin/env bash

# Log messages with appropriate prefixes
system_log() {
  local log_type="$1"
  local message="$2"
  local log_file="$3"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ${log_type}: ${message}" | tee -a "${log_file}"
}
