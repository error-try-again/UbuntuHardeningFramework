#!/usr/bin/env bash

# Log messages to a log file
log() {
  local message="$1"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - ${message}"
}
