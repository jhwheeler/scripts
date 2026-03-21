#!/bin/bash
# Rebuild rheo from a given branch (default: master) and restart services
# Usage: rheo-rebuild.sh [branch]
#
# This rebuilds the main binary at ~/go/bin/rheo and restarts:
#   - rheo _engine (if running)
#   - rheo-web.service (systemd user service, Tailscale HTTPS)

set -e

BRANCH="${1:-master}"
RHEO_DIR="$HOME/projects/rheo"
BINARY="$HOME/go/bin/rheo"

echo "=== Rheo Rebuild ==="
echo "Branch: $BRANCH"
echo "Source: $RHEO_DIR"
echo "Binary: $BINARY"
echo ""

# Pull latest
cd "$RHEO_DIR"
git fetch origin
git checkout "$BRANCH"
git pull origin "$BRANCH"

# Build
echo "Building..."
go build -o "$BINARY" ./cmd/rheo
echo "Built: $(ls -la "$BINARY" | awk '{print $6, $7, $8, $9}')"

# Rebuild web assets
echo "Building web assets..."
cd "$RHEO_DIR/web"
npm install --silent 2>/dev/null
npm run build --silent 2>/dev/null
echo "Web assets built."

# Restart engine (it runs as a background process, not systemd)
ENGINE_PID=$(pgrep -f "rheo _engine" || true)
if [ -n "$ENGINE_PID" ]; then
    echo "Stopping engine (PID $ENGINE_PID)..."
    kill "$ENGINE_PID" 2>/dev/null || true
    sleep 2
    # Engine should be restarted by whatever manages it (rheo run / rheo tui)
    echo "Engine stopped. It will restart on next rheo command."
else
    echo "No engine process found."
fi

# Restart web service
echo "Restarting rheo-web service..."
systemctl --user restart rheo-web.service
sleep 2
systemctl --user status rheo-web.service --no-pager | head -10

echo ""
echo "=== Rebuild complete ==="
echo "Branch: $BRANCH"
echo "Binary: $BINARY"
