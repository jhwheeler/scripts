#!/bin/bash

# Check if the Keychron V3 keyboard device exists
if [ -e "/dev/input/by-id/usb-Keychron_Keychron_V3-event-kbd" ]; then
    # Kill existing kmonad process for this keyboard if it exists
    sudo pkill -f "kmonad.*config-keychron-v3.kbd"
    
    # Wait a moment
    sleep 1
    
    # Start kmonad for the Keychron V3 keyboard
    sudo kmonad ~/.config/kmonad/config-keychron-v3.kbd &
    
    echo "Started kmonad for Keychron V3 keyboard"
else
    echo "Keychron V3 keyboard not found"
fi
