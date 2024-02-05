#!/usr/bin/env bash

# Restart a service
restart_service() {
  local service_name="$1"
  systemctl restart "${service_name}" --no-pager
}
