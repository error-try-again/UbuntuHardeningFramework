#!/usr/bin/env bash

# Retrieve service status
status_service() {
  local service_name="$1"
  systemctl status "${service_name}" --no-pager
}
