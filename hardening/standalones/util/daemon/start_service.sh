#!/usr/bin/env bash

# Start a service
start_service() {
  local service_name="$1"
  systemctl start "${service_name}" --no-pager
}
