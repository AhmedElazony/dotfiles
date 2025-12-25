#!/bin/bash
# Fix HDMI monitor after suspend/resume
# Save this as ~/.config/hypr/scripts/fix-hdmi-resume.sh
# Make it executable: chmod +x ~/.config/hypr/scripts/fix-hdmi-resume.sh

case "$1" in
pre)
	# Before suspend - nothing needed
	;;
post)
	# After resume - reinitialize HDMI monitor
	sleep 2 # Give the system time to detect the monitor

	# Reload Hyprland to reinitialize monitors
	hyprctl reload && hyprctl reload

	# Alternative: Just reset the HDMI monitor
	# hyprctl keyword monitor "HDMI-A-1,1920x1080@144.01,auto,auto"
	;;
esac
