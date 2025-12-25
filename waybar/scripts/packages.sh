#!/bin/bash
# filepath: /home/ahmedelazony/.config/waybar/scripts/packages.sh

# Get total packages
total_packages=$(pacman -Q | wc -l)

# Check for updates
updates=$(checkupdates 2>/dev/null | wc -l)

if [ "$updates" -gt 0 ]; then
    echo "$total_packages  $updates"
    echo "Updates available: $updates packages"
    echo "updates-available"
else
    echo "$total_packages"
    echo "No updates available ($total_packages packages installed)"
    echo "up-to-date"
fi