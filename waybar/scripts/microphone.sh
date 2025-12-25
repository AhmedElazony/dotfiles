#!/bin/bash
# filepath: /home/ahmedelazony/.config/waybar/scripts/microphone.sh

# Check if microphone is being used
mic_active=$(pactl list source-outputs | grep -c "Source Output")

if [ "$mic_active" -gt 0 ]; then
    # Microphone is active
    echo "󰍬"
    echo "Microphone in use"
    echo "mic-active"
else
    # No microphone activity
    echo ""
    echo "Microphone not in use"
    echo "mic-inactive"
fi