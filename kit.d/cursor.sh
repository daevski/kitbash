#!/bin/bash

# Cursor theme setup script
# Sets up Breeze cursor theme for Sway/Wayland

CURSOR_THEME="${1:-breeze_cursors}"
CURSOR_SIZE="${2:-24}"

# Check if cursor theme exists, if not try to install it
if [ ! -d "/usr/share/icons/$CURSOR_THEME" ] && [ ! -d "$HOME/.local/share/icons/$CURSOR_THEME" ]; then
    log_step "cursor theme '$CURSOR_THEME' not found, installing"
    log_debug "Checking paths: /usr/share/icons/$CURSOR_THEME and $HOME/.local/share/icons/$CURSOR_THEME"

    # Install breeze cursor theme package
    if ! run_with_progress "installing breeze cursor theme" sudo dnf install -y breeze-cursor-theme; then
        log_error "Failed to install breeze cursor theme via dnf"
        log_error "Available cursor themes in /usr/share/icons/:"
        ls /usr/share/icons/ | grep -i cursor || log_error "No cursor themes found"
        exit 1
    fi

    # Verify installation worked
    if [ ! -d "/usr/share/icons/$CURSOR_THEME" ] && [ ! -d "$HOME/.local/share/icons/$CURSOR_THEME" ]; then
        log_error "Cursor theme '$CURSOR_THEME' still not found after installation attempt"
        exit 1
    fi
fi

# Set cursor theme using gsettings
if run_with_progress "setting cursor theme via gsettings" gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME"; then
    log_debug "Cursor theme set via gsettings"
else
    log_debug "Failed to set cursor theme (gsettings not available)"
fi

if run_with_progress "setting cursor size via gsettings" gsettings set org.gnome.desktop.interface cursor-size "$CURSOR_SIZE"; then
    log_debug "Cursor size set via gsettings"
else
    log_debug "Failed to set cursor size (gsettings not available)"
fi

# Set environment variables for Electron/Chrome-based apps like VS Code
log_step "configuring cursor environment variables"

# Add to .profile for session-wide environment variables (better than .bashrc)
PROFILE_FILE="$HOME/.profile"

# Remove any existing cursor environment variables from both .profile and .bashrc
for file in "$HOME/.profile" "$HOME/.bashrc"; do
    if [ -f "$file" ]; then
        sed -i '/^export XCURSOR_THEME=/d' "$file"
        sed -i '/^export XCURSOR_SIZE=/d' "$file"
    fi
done

# Add to .profile (sourced by display managers and session managers)
echo "export XCURSOR_THEME=$CURSOR_THEME" >> "$PROFILE_FILE"
echo "export XCURSOR_SIZE=$CURSOR_SIZE" >> "$PROFILE_FILE"

# Set for current session
export XCURSOR_THEME="$CURSOR_THEME"
export XCURSOR_SIZE="$CURSOR_SIZE"

log_debug "Environment variables set in $PROFILE_FILE"

# Update GTK settings file for additional compatibility
GTK3_SETTINGS="$HOME/.config/gtk-3.0/settings.ini"
if [ -f "$GTK3_SETTINGS" ]; then
    log_step "updating GTK3 cursor settings"
    # Update existing file
    sed -i '/^gtk-cursor-theme-name=/d' "$GTK3_SETTINGS"
    sed -i '/^gtk-cursor-theme-size=/d' "$GTK3_SETTINGS"
    sed -i '/^\[Settings\]/a gtk-cursor-theme-name='"$CURSOR_THEME"'\ngtk-cursor-theme-size='"$CURSOR_SIZE" "$GTK3_SETTINGS"
    log_debug "Updated $GTK3_SETTINGS"
else
    log_debug "GTK3 settings file not found: $GTK3_SETTINGS"
fi

# Update systemd environment file
SYSTEMD_ENV_FILE="$HOME/.config/environment.d/cursor.conf"
if [ -f "$SYSTEMD_ENV_FILE" ]; then
    log_step "updating systemd cursor environment"
    sed -i "s|^XCURSOR_THEME=.*|XCURSOR_THEME=$CURSOR_THEME|" "$SYSTEMD_ENV_FILE"
    sed -i "s|^XCURSOR_SIZE=.*|XCURSOR_SIZE=$CURSOR_SIZE|" "$SYSTEMD_ENV_FILE"
    log_debug "Updated $SYSTEMD_ENV_FILE"
else
    log_debug "Systemd environment file not found: $SYSTEMD_ENV_FILE"
fi

# Configure for Sway if config exists
SWAY_CONFIG="$HOME/.config/sway/config"
if [ -f "$SWAY_CONFIG" ]; then
    log_step "configuring cursor for Sway"

    # Remove any existing cursor configuration
    sed -i '/^seat \* xcursor_theme/d' "$SWAY_CONFIG"

    # Find the line after the closing brace of the set block and add cursor config
    if grep -q "^}" "$SWAY_CONFIG"; then
        # Insert cursor configuration after the first closing brace
        sed -i '0,/^}$/s/^}$/&\n\n# Cursor configuration\nseat * xcursor_theme '"$CURSOR_THEME"' '"$CURSOR_SIZE"'/' "$SWAY_CONFIG"
        log_debug "Added cursor config to Sway config"

        # Reload Sway configuration if we're in a Sway session
        if [ "$XDG_CURRENT_DESKTOP" = "sway" ]; then
            if run_with_progress "reloading Sway configuration" swaymsg reload; then
                log_debug "Sway configuration reloaded"
            else
                log_debug "Failed to reload Sway (not in Sway session)"
            fi
        fi
    else
        log_warning "Could not find insertion point in Sway config"
    fi
else
    log_debug "Sway config not found, skipping Sway configuration"
fi

# Verify configuration
log_step "verifying cursor configuration"
CURRENT_THEME=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")
CURRENT_SIZE=$(gsettings get org.gnome.desktop.interface cursor-size 2>/dev/null)

if [ "$CURRENT_THEME" = "$CURSOR_THEME" ] && [ "$CURRENT_SIZE" = "$CURSOR_SIZE" ]; then
    log_debug "Cursor theme '$CURSOR_THEME' (size $CURSOR_SIZE) verified successfully"
else
    log_debug "Verification failed, but configuration may still work"
fi