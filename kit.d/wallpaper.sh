#!/bin/bash

# Check if wallpaper path is provided as first parameter
if [ -z "$1" ]; then
    log_error "No wallpaper path provided. Usage: $0 <wallpaper_path_or_name>"
    exit 1
fi

_wallpaper_input="$1"
log_debug "Wallpaper input: $_wallpaper_input"

# Function to resolve wallpaper name to URL from definitions
resolve_wallpaper_name() {
    local name="$1"
    for definition in "${_wallpaper_definitions[@]}"; do
        if [[ "$definition" == "$name:"* ]]; then
            echo "${definition#*:}"
            return 0
        fi
    done
    return 1
}

# Function to download wallpaper from URL
download_wallpaper() {
    local url="$1"
    local name="$2"
    
    # Extract file extension from URL (remove query parameters first)
    local url_without_params="${url%%\?*}"
    local extension="${url_without_params##*.}"
    # If no extension found, extension contains path separators, or extension is too long, default to jpg
    if [ -z "$extension" ] || [[ "$extension" == */* ]] || [ "${#extension}" -gt 4 ]; then
        extension="jpg"
    fi
    
    local output_file="$HOME/wallpaper.$extension"

    log_debug "Downloading from: $url to $output_file"

    if command -v curl >/dev/null 2>&1; then
        if run_with_progress "downloading wallpaper '$name'" curl -fsSL "$url" -o "$output_file"; then
            # Return the output file path via stdout (last line)
            echo "$output_file"
            return 0
        else
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if run_with_progress "downloading wallpaper '$name'" wget -q "$url" -O "$output_file"; then
            # Return the output file path via stdout (last line)
            echo "$output_file"
            return 0
        else
            return 1
        fi
    else
        log_error "No curl or wget available"
        return 1
    fi
}

# Resolve wallpaper input to actual file path and normalize to ~/wallpaper.(ext)
_wallpaper_source=""
if [[ "$_wallpaper_input" == *"/"* ]] && [ -f "$_wallpaper_input" ]; then
    # It's a file path that exists
    _wallpaper_source="$_wallpaper_input"
elif [ -f "$_wallpaper_input" ]; then
    # It's a file in current directory
    _wallpaper_source="$_wallpaper_input"
else
    # Try to resolve as predefined wallpaper name
    wallpaper_url=$(resolve_wallpaper_name "$_wallpaper_input")
    if [ $? -eq 0 ] && [ -n "$wallpaper_url" ]; then
        log_step "resolved '$_wallpaper_input' as predefined wallpaper"
        log_debug "Wallpaper URL: $wallpaper_url"
        # Download wallpaper - the function will print progress and return the file path
        download_output=$(download_wallpaper "$wallpaper_url" "$_wallpaper_input")
        download_exit_code=$?
        if [ $download_exit_code -eq 0 ]; then
            # Extract the file path from the last line of output
            _wallpaper_source=$(echo "$download_output" | tail -1)
            if [ -f "$_wallpaper_source" ]; then
                log_debug "Downloaded to: $_wallpaper_source"
            else
                log_error "Download succeeded but file not found: $_wallpaper_source"
                exit 1
            fi
        else
            log_error "Failed to download wallpaper"
            exit 1
        fi
    else
        log_error "'$_wallpaper_input' is not a valid file path or predefined wallpaper name"
        log_error ""
        if [ ${#_wallpaper_definitions[@]} -gt 0 ]; then
            log_error "Available predefined wallpapers:"
            for definition in "${_wallpaper_definitions[@]}"; do
                local name="${definition%%:*}"
                log_error "  - $name"
            done
        else
            log_error "No predefined wallpapers configured in kit.conf"
            log_error "Add wallpapers to _wallpaper_definitions array in the format:"
            log_error "  _wallpaper_definitions=("
            log_error "    \"name:https://example.com/wallpaper.jpg\""
            log_error "  )"
        fi
        exit 1
    fi
fi

# Final check if wallpaper source file exists
if [ ! -f "$_wallpaper_source" ]; then
    log_error "Wallpaper file '$_wallpaper_source' not found"
    exit 1
fi

# Normalize: Copy/move source to ~/wallpaper.(ext) for consistent naming
_source_ext="${_wallpaper_source##*.}"
_wallpaper_path="$HOME/wallpaper.$_source_ext"

# Only copy if it's not already at the target location
if [ "$_wallpaper_source" != "$_wallpaper_path" ]; then
    if ! run_with_progress "normalizing wallpaper to ~/wallpaper.$_source_ext" cp "$_wallpaper_source" "$_wallpaper_path"; then
        log_error "Failed to normalize wallpaper"
        exit 1
    fi
fi

# Use consistent naming for all operations
_wallpaper_name="wallpaper.$_source_ext"
_wallpaper_base="wallpaper"
_wallpaper_ext="$_source_ext"
log_debug "Normalized wallpaper path: $_wallpaper_path"

# Source the configuration to get wallpaper targets and definitions
if [ -f "$KITBASH_CONFIG" ]; then
    source "$KITBASH_CONFIG"
else
    log_error "Could not find kit.conf - required for wallpaper definitions"
    log_error "Please ensure kit.conf exists in your kitbash root directory"
    exit 1
fi

# Verify required variables are loaded
if [ -z "${_wallpaper_targets[*]}" ]; then
    log_warning "_wallpaper_targets not found in kit.conf, using defaults"
    _wallpaper_targets=("desktop" "lock" "login")
fi

if [ -z "${_wallpaper_definitions[*]}" ]; then
    log_warning "_wallpaper_definitions not found in kit.conf"
    log_warning "Predefined wallpaper names will not work"
    _wallpaper_definitions=()
fi

log_debug "Wallpaper targets: ${_wallpaper_targets[*]}"

# Check if ImageMagick is available for dimension detection
if ! command -v magick >/dev/null 2>&1; then
    log_warning "ImageMagick (magick command) not found. Cannot detect image dimensions."
    log_warning "Install with: sudo dnf install ImageMagick"
    _is_dual_monitor=false
else
    # Get image dimensions using ImageMagick
    log_step "detecting image dimensions"
    _dimensions=$(magick identify -format "%wx%h" "$_wallpaper_path")
    _exit_code=$?

    if [ $_exit_code -eq 0 ] && [ -n "$_dimensions" ]; then
        _width=$(echo "$_dimensions" | cut -d'x' -f1)
        _height=$(echo "$_dimensions" | cut -d'x' -f2)
        log_debug "Image dimensions: ${_width}x${_height}"

        # Calculate aspect ratio to determine if it's likely a dual monitor setup
        # Typical dual monitor setups: 3840x1080 (2x1920x1080), 2560x1024 (2x1280x1024), etc.
        # Look for aspect ratios wider than 2.5:1 (normal widescreen is ~1.78:1)
        if command -v bc >/dev/null 2>&1; then
            _aspect_ratio=$(echo "scale=2; $_width / $_height" | bc -l 2>/dev/null || echo "0")
            _aspect_check=$(echo "$_aspect_ratio > 2.5" | bc -l 2>/dev/null || echo "0")
        else
            # Fallback calculation without bc (less precise)
            _aspect_times_10=$((($_width * 10) / $_height))
            if [ $_aspect_times_10 -gt 25 ]; then
                _aspect_check="1"
                _aspect_ratio="$_aspect_times_10.0/10"
            else
                _aspect_check="0"
                _aspect_ratio="$_aspect_times_10.0/10"
            fi
        fi

        if [ "$_aspect_check" = "1" ]; then
            log_debug "Detected ultra-wide aspect ratio ($_aspect_ratio:1) - likely dual monitor wallpaper"
            _is_dual_monitor=true
        else
            log_debug "Detected standard aspect ratio ($_aspect_ratio:1) - single monitor wallpaper"
            _is_dual_monitor=false
        fi
    else
        log_debug "Failed to detect dimensions"
        # Fallback to filename detection
        if [[ "$_wallpaper_name" == *"dual"* ]] || [[ "$_wallpaper_name" == *"monitor"* ]] || [[ "$_wallpaper_name" == *"wide"* ]]; then
            log_debug "Fallback: detected dual monitor keywords in filename"
            _is_dual_monitor=true
        else
            _is_dual_monitor=false
        fi
    fi
fi

# Define system paths for the wallpapers
_system_wallpaper_dir="/usr/share/backgrounds"
_system_wallpaper="$_system_wallpaper_dir/$_wallpaper_name"
_system_split_0="$_system_wallpaper_dir/${_wallpaper_base}-0.${_wallpaper_ext}"
_system_split_1="$_system_wallpaper_dir/${_wallpaper_base}-1.${_wallpaper_ext}"
log_debug "System wallpaper paths: $_system_wallpaper, $_system_split_0, $_system_split_1"

# Copy original wallpaper to system directory (needed for all targets)
if ! run_with_progress "copying wallpaper to system directory" sudo cp "$_wallpaper_path" "$_system_wallpaper"; then
    log_error "Failed to copy wallpaper to system directory"
    exit 1
fi

# Handle dual monitor wallpaper splitting if needed for desktop target
if [ "$_is_dual_monitor" = true ] && [[ " ${_wallpaper_targets[*]} " == *" desktop "* ]]; then
    log_step "detected dual monitor wallpaper for Sway desktop"

    # Check if split versions need to be created/updated
    # Create if they don't exist OR if the main wallpaper is newer than the split versions
    if [ ! -f "$_system_split_0" ] || [ ! -f "$_system_split_1" ] || [ "$_system_wallpaper" -nt "$_system_split_0" ]; then
        log_debug "Creating/updating split wallpapers"

        # Check if ImageMagick is available
        if ! command -v magick >/dev/null 2>&1; then
            log_error "ImageMagick (magick command) not found. Please install it: sudo dnf install ImageMagick"
            exit 1
        fi

        if ! run_with_progress "splitting wallpaper into dual monitor versions" sudo magick "$_system_wallpaper" -crop 50%x100% +repage +adjoin "${_system_wallpaper_dir}/${_wallpaper_base}-%d.${_wallpaper_ext}"; then
            log_error "Failed to split wallpaper"
            exit 1
        fi

        # Verify split files were created
        if [ ! -f "$_system_split_0" ] || [ ! -f "$_system_split_1" ]; then
            log_error "Split wallpaper files not created properly"
            exit 1
        fi
    else
        log_debug "Split wallpapers already exist in system directory"
    fi
fi

# Function to configure Sway desktop wallpaper
configure_sway_desktop() {
    SWAY_CONFIG="$HOME/.config/sway/config"
    if [ ! -f "$SWAY_CONFIG" ]; then
        log_debug "Sway config not found at $SWAY_CONFIG"
        return 1
    fi

    if [ "$_is_dual_monitor" = true ]; then
        # Check for existing output lines with bg settings
        if grep -q "^output.*bg.*" "$SWAY_CONFIG"; then
            log_step "updating Sway desktop (dual monitor)"
            log_debug "Updating Sway output lines for dual monitor wallpapers"

            # Update existing output lines to use the system split wallpapers
            sed -i "s|^output HDMI-A-1.*bg.*|output HDMI-A-1 pos    0 0 bg $_system_split_0 fill|" "$SWAY_CONFIG"
            sed -i "s|^output HDMI-A-2.*bg.*|output HDMI-A-2 pos 1920 0 bg $_system_split_1 fill|" "$SWAY_CONFIG"
        else
            log_warning "No Sway output configurations found with wallpaper settings"
            log_warning "Dual monitor wallpapers created but not applied to Sway config"
        fi
    else
        # Single monitor wallpaper handling
        if grep -q "^output.*bg.*" "$SWAY_CONFIG"; then
            log_step "updating Sway desktop (single monitor)"
            log_debug "Updating Sway output lines for single wallpaper"

            # Update existing output lines to use the same single wallpaper on both monitors
            sed -i "s|^output HDMI-A-1.*bg.*|output HDMI-A-1 pos    0 0 bg $_system_wallpaper fill|" "$SWAY_CONFIG"
            sed -i "s|^output HDMI-A-2.*bg.*|output HDMI-A-2 pos 1920 0 bg $_system_wallpaper fill|" "$SWAY_CONFIG"
        fi
    fi
}

# Function to configure swaylock wallpaper
configure_swaylock() {
    SWAYLOCK_CONFIG="$HOME/.config/swaylock/config"
    SWAY_CONFIG="$HOME/.config/sway/config"

    if [ ! -f "$SWAYLOCK_CONFIG" ]; then
        log_debug "Swaylock config not found at $SWAYLOCK_CONFIG"
        return 1
    fi

    # Choose appropriate wallpaper for lock screen
    local lock_wallpaper
    if [ "$_is_dual_monitor" = true ]; then
        # Use first half of split image for lock screen (looks better than full-width stretched)
        lock_wallpaper="$_system_split_0"
    else
        lock_wallpaper="$_system_wallpaper"
    fi

    log_step "updating swaylock configuration"
    log_debug "Lock wallpaper: $lock_wallpaper"

    # Update only the image path in existing swaylock config
    sed -i "s|^image=.*|image=$lock_wallpaper|" "$SWAYLOCK_CONFIG"

    # Update Sway config to use simple swaylock commands (swaylock will read its own config)
    if [ -f "$SWAY_CONFIG" ]; then
        # Update swayidle configuration to use simple swaylock command
        sed -i "s|swaylock -f -i [^']*|swaylock -f|g" "$SWAY_CONFIG"
        sed -i "s|swaylock -f -c [^']*|swaylock -f|g" "$SWAY_CONFIG"

        # Update manual lock keybinding to use simple swaylock command
        sed -i "s|\$mod+l exec swaylock[^\"]*|\$mod+l exec swaylock -f|" "$SWAY_CONFIG"
    fi
}

# Function to configure SDDM wallpaper
configure_sddm() {
    SDDM_THEME_CONFIG="/usr/share/sddm/themes/custom/theme.conf"
    if [ ! -f "$SDDM_THEME_CONFIG" ]; then
        log_debug "SDDM custom theme config not found at $SDDM_THEME_CONFIG"
        return 1
    fi

    # Choose appropriate wallpaper for login screen
    local login_wallpaper
    if [ "$_is_dual_monitor" = true ]; then
        # Use first half of split image for login screen (looks better than full-width stretched)
        login_wallpaper="$_system_split_0"
    else
        login_wallpaper="$_system_wallpaper"
    fi

    log_step "updating SDDM login screen"
    log_debug "Login wallpaper: $login_wallpaper"

    if ! sudo sed -i "s|^background=.*|background=$login_wallpaper|" "$SDDM_THEME_CONFIG"; then
        log_error "Failed to update SDDM theme (insufficient permissions)"
        return 1
    fi

    # Ensure SDDM is configured to use the custom theme
    SDDM_CONFIG="/etc/sddm.conf"
    if [ -f "$SDDM_CONFIG" ] && ! sudo grep -q "^Current=custom" "$SDDM_CONFIG"; then
        log_debug "Configuring SDDM to use custom theme"
        if ! sudo sed -i 's|#Current=.*|Current=custom|' "$SDDM_CONFIG"; then
            log_error "Failed to configure SDDM (insufficient permissions)"
            return 1
        fi
    fi
}

# Apply wallpaper to specified targets
log_debug "Applying wallpaper to targets: ${_wallpaper_targets[*]}"
for target in "${_wallpaper_targets[@]}"; do
    case "$target" in
        "desktop")
            configure_sway_desktop
            ;;
        "lock")
            configure_swaylock
            ;;
        "login")
            configure_sddm
            ;;
        *)
            log_warning "Unknown wallpaper target '$target'"
            ;;
    esac
done

# Create default symlink for compatibility (only if not dual monitor or desktop not in targets)
if [ "$_is_dual_monitor" = false ] || [[ ! " ${_wallpaper_targets[*]} " == *" desktop "* ]]; then
    # Remove existing default wallpaper if it exists and is not our target
    if [ -f "/usr/share/backgrounds/default" ] && [ "$(readlink /usr/share/backgrounds/default)" != "$_system_wallpaper" ]; then
        log_debug "Removing old default wallpaper symlink"
        sudo rm -f /usr/share/backgrounds/default
    fi

    # Create symlink to new wallpaper
    if ! run_with_progress "setting as system default wallpaper" sudo ln -sf "$_system_wallpaper" /usr/share/backgrounds/default; then
        log_error "Failed to create wallpaper symlink"
    fi
fi

# Reload Sway configuration if any Sway-related targets were configured
if [[ " ${_wallpaper_targets[*]} " == *" desktop "* ]] || [[ " ${_wallpaper_targets[*]} " == *" lock "* ]]; then
    if [ "$XDG_CURRENT_DESKTOP" = "sway" ]; then
        if run_with_progress "reloading Sway configuration" swaymsg reload; then
            log_debug "Sway configuration reloaded successfully"
        else
            log_debug "Failed to reload Sway (not in Sway session or swaymsg not available)"
        fi
    fi
fi