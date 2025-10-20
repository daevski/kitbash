#!/bin/bash

# Check if hostname is provided as first parameter
if [ -z "$1" ]; then
    log_error "No hostname provided. Usage: $0 <new_hostname>"
    exit 1
fi

# Update hostname
new_hostname="$1"
log_debug "Setting hostname to: $new_hostname"

if ! run_with_progress "updating hostname to '$new_hostname'" sudo hostnamectl hostname "$1"; then
    log_error "Failed to update hostname"
    exit 1
fi

# Verify update
if [ "$(hostname)" = "$1" ]; then
    log_debug "Hostname verified: $new_hostname"
else
    log_error "Failed to verify hostname update"
    exit 1
fi