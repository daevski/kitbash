#!/bin/bash
# Font Installation Module
# Downloads and installs fonts from predefined URLs or local paths

FONT_NAME="${1:-$_font}"

if [ -z "$FONT_NAME" ]; then
    log_error "No font specified"
    return 1
fi

log_step "installing font: $FONT_NAME"
log_debug "Font name: $FONT_NAME"

# Ensure fonts directory exists
FONTS_DIR="$HOME/.local/share/fonts"
log_debug "Fonts directory: $FONTS_DIR"
mkdir -p "$FONTS_DIR"

# Check if it's a predefined font
FONT_URL=""
for definition in "${_font_definitions[@]}"; do
    name="${definition%%:*}"
    url="${definition#*:}"
    if [ "$name" = "$FONT_NAME" ]; then
        FONT_URL="$url"
        break
    fi
done

if [ -z "$FONT_URL" ]; then
    log_error "Font '$FONT_NAME' not found in predefined fonts"
    log_error "Available fonts:"
    for definition in "${_font_definitions[@]}"; do
        name="${definition%%:*}"
        log_error "  - $name"
    done
    return 1
fi

log_debug "Font URL: $FONT_URL"

# Download to temp directory
TEMP_DIR=$(mktemp -d)
log_debug "Temp directory: $TEMP_DIR"
cd "$TEMP_DIR"

# Download the font
FONT_FILE=$(basename "$FONT_URL")
log_debug "Downloading to: $FONT_FILE"

if ! run_with_progress "downloading font" wget -q "$FONT_URL" -O "$FONT_FILE"; then
    log_error "Failed to download font"
    rm -rf "$TEMP_DIR"
    return 1
fi

# Handle zip files
if [[ "$FONT_FILE" == *.zip ]]; then
    EXTRACT_DIR="font_extracted"
    mkdir -p "$EXTRACT_DIR"

    if ! run_with_progress "extracting archive" unzip -q "$FONT_FILE" -d "$EXTRACT_DIR"; then
        log_error "Failed to extract font archive"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Copy all font files to fonts directory
    log_step "copying font files"
    log_debug "Finding font files in $EXTRACT_DIR"
    find "$EXTRACT_DIR" -type f \( -name "*.ttf" -o -name "*.otf" -o -name "*.TTF" -o -name "*.OTF" \) -exec cp {} "$FONTS_DIR/" \;
else
    # Not a zip, assume it's a direct font file
    log_step "copying font file"
    cp "$FONT_FILE" "$FONTS_DIR/"
fi

# Clean up
cd - > /dev/null
log_debug "Cleaning up temp directory: $TEMP_DIR"
rm -rf "$TEMP_DIR"

# Rebuild font cache
run_with_progress "rebuilding font cache" fc-cache -fv
