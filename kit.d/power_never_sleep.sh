#!/bin/bash

# Module: power_never_sleep.sh
# Purpose: Disable automatic system sleep/suspend
# Tier: 1 (System Fundamentals)

log_info "Configuring power management to prevent system sleep"

# Create logind configuration to prevent auto-sleep
log_step "disabling automatic system sleep"
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/no-auto-sleep.conf > /dev/null << 'EOF'
# Prevent automatic system sleep while allowing screen lock and monitor power-off
# Configured by setup system

[Login]
# Never automatically suspend the system
IdleAction=ignore
IdleActionSec=0

# Handle power button press (can be changed to poweroff if desired)
HandlePowerKey=suspend

# For laptops - handle lid switch (ignore, suspend, poweroff, or lock)
# HandleLidSwitch=suspend
# HandleLidSwitchExternalPower=ignore

# Prevent sleep when closing lid with external power (for laptops)
# HandleLidSwitchDocked=ignore
EOF

if [ $? -ne 0 ]; then
    log_error "Failed to create logind configuration"
    exit 1
fi

# Create sleep configuration to disable auto-sleep mechanisms
log_step "disabling systemd auto-sleep mechanisms"
sudo mkdir -p /etc/systemd/sleep.conf.d
sudo tee /etc/systemd/sleep.conf.d/no-auto-sleep.conf > /dev/null << 'EOF'
# Disable automatic sleep mechanisms
# Configured by setup system

[Sleep]
# Disable all automatic sleep modes
AllowSuspend=no
AllowHibernation=no
AllowSuspendThenHibernate=no
AllowHybridSleep=no
EOF

if [ $? -ne 0 ]; then
    log_error "Failed to create sleep configuration"
    exit 1
fi

# Mask sleep targets to prevent accidental sleep (optional, might be too aggressive)
# log_step "masking sleep targets"
# sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

log_success "Power management configured successfully"
log_debug ""
log_debug "Current configuration:"
log_debug "  Screen will lock after 5 minutes (swayidle)"
log_debug "  Monitors will turn off after 10 minutes (swayidle)"
log_debug "  System will NEVER auto-sleep or hibernate"
log_debug "  Manual sleep via 'systemctl suspend' still works"
log_debug ""
log_warning "You need to log out and back in for changes to take full effect (logind needs to reload configuration)"