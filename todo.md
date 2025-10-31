# Kitbash TODO

## Issues Found During Fresh Install

### 1. Wallpaper Module Not Running
- **Issue**: `_wallpaper` is configured in kit.conf but wallpaper module didn't run during setup
- **Config**: `_wallpaper='minimal-colored-circles'`
- **Expected**: Should download and apply wallpaper during `kit --setup`
- **Investigation needed**: Check if wallpaper module is being called by module-runner
- **Debug**: Check `kitbash/kit.log` for execution details

### 2. CopyQ Not Installed
- **Issue**: CopyQ clipboard manager is not installed or configured
- **Sway config references**: `exec copyq` and `Ctrl+Alt+backslash` binding
- **Module status**: No copyq module exists in kit.d/
- **Action needed**: Create copyq.sh module to install and auto-start copyq

### 3. Potential Other Missing Autostart Items
Items from Sway config that may need modules or startup configuration:
- `wlsunset` - Night light/color temperature (line 34)
- `waybar` - Status bar (line 39)
- `swayidle` - Idle management (line 15, 38)
- Screenshot tools: `grim`, `slurp`, `swappy`

## Completed

### Niri Module
- ✅ Created niri.sh installation module
- ✅ Added to kit.conf.example
- ✅ Fixed Wayland dependency detection
- ✅ Tested installation from COPR

### Documentation
- ✅ Created CLAUDE.md with comprehensive system architecture docs
- ✅ Removed *todo.md from .gitignore to track issues across reinstalls

## In Progress

### Niri Configuration
- Migrating Sway keybindings to Niri config
- Adjusting for Niri's column-based paradigm vs Sway's tiling

## Future Enhancements

### Potential Modules to Create
- [ ] CopyQ clipboard manager
- [ ] Waybar status bar configuration
- [ ] wlsunset/night light
- [ ] Screenshot tool stack (grim + slurp + swappy)
- [ ] swayidle configuration
- [ ] General Wayland utilities meta-module

### System Improvements
- [ ] Investigate why some modules don't run during `kit --setup`
- [ ] Add better logging for module execution flow
- [ ] Consider pre-flight checks for desktop environment compatibility
