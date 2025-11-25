#!/bin/bash
# Initialize Wine properly before running the main setup
# Run this FIRST if Wine initialization fails

set -e

echo "🍷 Initializing Wine from Scratch"
echo "=================================="

export WINEPREFIX="$HOME/.wine"
export WINEDEBUG="-all"

# Remove old Wine prefix if it's corrupted
if [ -d "$WINEPREFIX" ]; then
    echo "⚠️  Existing Wine prefix found"
    read -p "Remove and recreate? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Removing old Wine prefix..."
        rm -rf "$WINEPREFIX"
    fi
fi

# Install Xvfb if not installed
if ! command -v Xvfb >/dev/null 2>&1; then
    echo "📦 Installing Xvfb..."
    apt-get install -y xvfb
fi

# Start virtual display
echo "🖥️  Starting virtual display..."
export DISPLAY=:99
if ! pgrep -x Xvfb > /dev/null; then
    Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
    sleep 3
    echo "✅ Virtual display started"
else
    echo "✅ Virtual display already running"
fi

# Initialize Wine
echo "🍷 Initializing Wine (this may take a minute)..."
DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wineboot --init >/dev/null 2>&1 || {
    echo "⚠️  wineboot failed, trying winecfg..."
    DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" winecfg -v win10 >/dev/null 2>&1 || true
}

sleep 2

# Test Wine
echo "🧪 Testing Wine..."
if DISPLAY=:99 wine --version >/dev/null 2>&1; then
    echo "✅ Wine initialized successfully!"
    echo "   Version: $(DISPLAY=:99 wine --version)"
    echo ""
    echo "✅ You can now run: ./CORRECT_MT5_SETUP.sh"
else
    echo "❌ Wine initialization failed"
    echo "   Try: apt-get install --reinstall wine wine64"
    exit 1
fi



