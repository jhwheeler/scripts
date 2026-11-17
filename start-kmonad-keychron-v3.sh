#!/bin/bash

DEVICE="/dev/input/by-id/usb-Keychron_Keychron_V3-event-kbd"
PATTERN="kmonad.*config-keychron-v3.kbd"

# Check if the Keychron V3 keyboard device exists
if [ -e "$DEVICE" ]; then
    # Kill existing kmonad process for this keyboard if it exists
    sudo pkill -f "$PATTERN"

    # Wait for it to exit and release the device
    for _ in {1..50}; do
        pgrep -f "$PATTERN" > /dev/null || break
        sleep 0.1
    done

    # A key held while kmonad grabs the device never gets its release
    # delivered to the compositor and stays stuck, so wait until every key
    # has been up for 300 ms.
    if ! python3 - "$DEVICE" <<'EOF'
import fcntl, os, sys, time

EVIOCGKEY = (2 << 30) | (96 << 16) | (ord("E") << 8) | 0x18
fd = os.open(sys.argv[1], os.O_RDONLY | os.O_NONBLOCK)
keys = bytearray(96)
deadline = time.monotonic() + 10
released_at = None
while time.monotonic() < deadline:
    fcntl.ioctl(fd, EVIOCGKEY, keys)
    now = time.monotonic()
    if any(keys):
        released_at = None
    elif released_at is None:
        released_at = now
    elif now - released_at >= 0.3:
        sys.exit(0)
    time.sleep(0.01)
sys.exit(1)
EOF
    then
        echo "Could not confirm all keys are released on the Keychron V3; kmonad not started"
        exit 1
    fi

    # Start kmonad for the Keychron V3 keyboard; the wait above replaces the start delay
    sudo kmonad --start-delay 0 ~/.config/kmonad/config-keychron-v3.kbd &

    echo "Started kmonad for Keychron V3 keyboard"
else
    echo "Keychron V3 keyboard not found"
fi
