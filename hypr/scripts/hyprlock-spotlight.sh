#!/bin/bash

WALLPAPER_DIR="$HOME/.local/share/wallpapers/spotlight/"
SYMLINK_PATH="$HOME/.cache/current-hyprlock-wallpaper.jpg"

# Get random wallpaper
wallpaper=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null | shuf -n 1)

# Fallback if no wallpaper found
if [[ -z "$wallpaper" || ! -f "$wallpaper" ]]; then
  wallpaper="$HOME/Pictures/wallpapers/best-wallpaper.jpg"
fi

# Create symlink
ln -sf "$wallpaper" "$SYMLINK_PATH"
