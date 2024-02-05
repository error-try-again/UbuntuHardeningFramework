#!/usr/bin/env bash

# Checks if the script is being run as root (used for apt)
check_root() {
  if [[ ${EUID} -ne 0   ]]; then
    echo "Please run as root"
    exit 1
  fi
}
