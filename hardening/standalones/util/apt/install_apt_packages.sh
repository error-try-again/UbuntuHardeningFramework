#!/usr/bin/env bash

# Installs a list of apt packages
install_apt_packages() {
  local package_list=($@) # Capture all arguments as an array of packages
  apt update -y || { log "Failed to update package lists..."; exit 1; }
  local package
  for package in "${package_list[@]}"; do
    if dpkg -l | grep -qw "$package"; then
      log "${package} is already installed."
    else
      if apt install -y "$package"; then
        log "Successfully installed ${package}."
      else
        log "Failed to install ${package}..."
        exit 1
      fi
    fi
  done
}
