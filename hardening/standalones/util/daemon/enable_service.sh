#!/usr/bin/env bash

# Enable and start a service
enable_service() {
  local service_name="$1"
  systemctl enable "${service_name}" --no-pager
}
