#!/bin/bash

# Module: niri.sh
# Purpose: Install Niri scrollable-tiling Wayland compositor and idle/lock tools
# Niri is a modern Wayland compositor with a unique scrollable tiling layout
# Also installs hyprlock/hypridle for screen locking and idle management

log_info "Setting up Niri window manager"

# Check if Niri is already installed
NIRI_INSTALLED=false
if command -v niri >/dev/null 2>&1; then
    NIRI_VERSION=$(niri --version 2>&1 | head -n1 || echo "unknown")
    log_debug "Niri is already installed: $NIRI_VERSION"
    NIRI_INSTALLED=true
fi

# Check if hypridle/hyprlock are already installed
HYPRIDLE_INSTALLED=false
HYPRLOCK_INSTALLED=false
if command -v hypridle >/dev/null 2>&1; then
    log_debug "hypridle is already installed"
    HYPRIDLE_INSTALLED=true
fi
if command -v hyprlock >/dev/null 2>&1; then
    log_debug "hyprlock is already installed"
    HYPRLOCK_INSTALLED=true
fi

# If everything is already installed and configured, exit early
if $NIRI_INSTALLED && $HYPRIDLE_INSTALLED && $HYPRLOCK_INSTALLED && \
   [ -f "$HOME/.config/hypr/hypridle.conf" ] && \
   [ -f "$HOME/.config/hypr/hyprlock.conf" ]; then
    log_success "Niri and lock/idle tools are already installed and configured"
    exit 0
fi

# Check if running on Wayland-compatible system
log_step "checking system compatibility"
if ! rpm -q libwayland-client >/dev/null 2>&1; then
    log_warning "Wayland libraries not detected, installing base dependencies"
    if ! run_with_progress "installing Wayland dependencies" \
        sudo dnf install -y wayland-devel libwayland-client libwayland-server; then
        log_error "Failed to install Wayland dependencies"
        exit $KIT_EXIT_DEPENDENCY_MISSING
    fi
else
    log_debug "Wayland libraries detected"
fi

# Enable COPR repository for Niri
log_step "enabling COPR repository for Niri"
if ! dnf copr list 2>/dev/null | grep -q "yalter/niri"; then
    if ! run_with_progress "adding yalter/niri COPR repository" \
        sudo dnf copr enable -y yalter/niri; then
        log_error "Failed to enable COPR repository for Niri"
        log_error "You may need to enable COPR manually: sudo dnf copr enable yalter/niri"
        exit $KIT_EXIT_NETWORK_ERROR
    fi
else
    log_debug "COPR repository already enabled"
fi

# Install Niri if needed
if ! $NIRI_INSTALLED; then
    log_step "installing Niri from COPR"
    if ! run_with_progress "installing niri package" \
        sudo dnf install -y niri; then
        log_error "Failed to install Niri"
        log_error "Check ~/kit.log for details"
        exit $KIT_EXIT_MODULE_FAILED
    fi

    # Verify installation
    if command -v niri >/dev/null 2>&1; then
        NIRI_VERSION=$(niri --version 2>&1 | head -n1 || echo "installed")
        log_debug "Niri installed successfully: $NIRI_VERSION"
    else
        log_error "Niri installation verification failed"
        exit $KIT_EXIT_MODULE_FAILED
    fi
fi

# Install hypridle and hyprlock if needed
if ! $HYPRIDLE_INSTALLED || ! $HYPRLOCK_INSTALLED; then
    log_step "installing hypridle and hyprlock"
    PACKAGES_TO_INSTALL=""
    if ! $HYPRIDLE_INSTALLED; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL hypridle"
    fi
    if ! $HYPRLOCK_INSTALLED; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL hyprlock"
    fi

    if ! run_with_progress "installing idle/lock tools" \
        sudo dnf install -y $PACKAGES_TO_INSTALL; then
        log_error "Failed to install hypridle/hyprlock"
        log_error "Check ~/kit.log for details"
        exit $KIT_EXIT_MODULE_FAILED
    fi

    # Verify installation
    if ! command -v hypridle >/dev/null 2>&1 || ! command -v hyprlock >/dev/null 2>&1; then
        log_error "hypridle/hyprlock installation verification failed"
        exit $KIT_EXIT_MODULE_FAILED
    fi
    log_debug "hypridle and hyprlock installed successfully"
fi

# Create config directory
log_step "setting up configuration files"
mkdir -p "$HOME/.config/hypr"

# Install hypridle config
if [ ! -f "$HOME/.config/hypr/hypridle.conf" ]; then
    log_debug "creating hypridle configuration"
    cat > "$HOME/.config/hypr/hypridle.conf" << 'EOF'
# Hypridle Configuration
# Idle management daemon - works across Hyprland, Niri, and Sway

general {
    lock_cmd = pidof hyprlock || hyprlock       # avoid starting multiple hyprlock instances
    before_sleep_cmd = loginctl lock-session    # lock before suspend
    after_sleep_cmd = sh -c 'if command -v hyprctl >/dev/null 2>&1; then hyprctl dispatch dpms on; elif command -v niri >/dev/null 2>&1; then niri msg action power-on-monitors; elif command -v swaymsg >/dev/null 2>&1; then swaymsg "output * dpms on"; fi'
}

# Lock screen after 5 minutes (300 seconds)
listener {
    timeout = 300
    on-timeout = loginctl lock-session
}

# Turn off monitors after 10 minutes (600 seconds)
listener {
    timeout = 600
    on-timeout = sh -c 'if command -v hyprctl >/dev/null 2>&1; then hyprctl dispatch dpms off; elif command -v niri >/dev/null 2>&1; then niri msg action power-off-monitors; elif command -v swaymsg >/dev/null 2>&1; then swaymsg "output * dpms off"; fi'
    on-resume = sh -c 'if command -v hyprctl >/dev/null 2>&1; then hyprctl dispatch dpms on; elif command -v niri >/dev/null 2>&1; then niri msg action power-on-monitors; elif command -v swaymsg >/dev/null 2>&1; then swaymsg "output * dpms on"; fi'
}
EOF
else
    log_debug "hypridle.conf already exists, skipping"
fi

# Install hyprlock config
if [ ! -f "$HOME/.config/hypr/hyprlock.conf" ]; then
    log_debug "creating hyprlock configuration"
    cat > "$HOME/.config/hypr/hyprlock.conf" << 'EOF'
# Hyprlock Configuration
# Screen locker for Hyprland

# General settings
general {
    disable_loading_bar = false
    hide_cursor = true
    grace = 0
    no_fade_in = false
}

# Background (Catppuccin Frappé base color)
background {
    monitor =
    path = /usr/share/backgrounds/wallpaper.jpg
    blur_passes = 2
    blur_size = 7
    noise = 0.0117
    contrast = 0.8916
    brightness = 0.8172
    vibrancy = 0.1696
    vibrancy_darkness = 0.0
}

# Input field
input-field {
    monitor =
    size = 300, 50
    outline_thickness = 2
    dots_size = 0.2
    dots_spacing = 0.35
    dots_center = true
    outer_color = rgb(ca9ee6)  # lavender
    inner_color = rgb(303446)  # base
    font_color = rgb(c6d0f5)   # text
    fade_on_empty = false
    placeholder_text = <span foreground="##c6d0f5">Enter Password...</span>
    hide_input = false
    position = 0, -120
    halign = center
    valign = center
    check_color = rgb(a6d189)  # green
    fail_color = rgb(e78284)   # red
    fail_text = <span foreground="##e78284">Authentication Failed</span>
    capslock_color = rgb(ef9f76)  # peach
}

# Time label
label {
    monitor =
    text = cmd[update:1000] echo "$(date +'%H:%M')"
    color = rgb(c6d0f5)  # text
    font_size = 120
    font_family = AudioLink Mono
    position = 0, 300
    halign = center
    valign = center
}

# Date label
label {
    monitor =
    text = cmd[update:60000] echo "$(date +'%A, %B %d')"
    color = rgb(c6d0f5)  # text
    font_size = 24
    font_family = AudioLink Mono
    position = 0, 200
    halign = center
    valign = center
}

# User label
label {
    monitor =
    text = $USER
    color = rgb(babbf1)  # lavender
    font_size = 18
    font_family = AudioLink Mono
    position = 0, -200
    halign = center
    valign = center
}
EOF
else
    log_debug "hyprlock.conf already exists, skipping"
fi

# Enable and start hypridle service
log_step "enabling hypridle service"
if ! systemctl --user is-enabled hypridle >/dev/null 2>&1; then
    if ! run_with_progress "enabling hypridle service" \
        systemctl --user enable hypridle; then
        log_warning "Failed to enable hypridle service"
    fi
fi

if ! systemctl --user is-active hypridle >/dev/null 2>&1; then
    if ! run_with_progress "starting hypridle service" \
        systemctl --user start hypridle; then
        log_warning "Failed to start hypridle service (may be compositor-specific)"
    fi
fi

log_success "Niri installation and configuration completed successfully"
log_info "Note: hypridle may show warnings when not in Hyprland - this is expected"
exit 0
