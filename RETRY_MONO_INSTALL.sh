#!/bin/bash
# Retry Mono installation with better error handling

set -e

export WINEPREFIX="$HOME/.wine"
export WINEDEBUG="-all"
export DISPLAY=:99
MONO_URL="https://dl.winehq.org/wine/wine-mono/10.3.0/wine-mono-10.3.0-x86.msi"

echo "🔄 Retrying Mono Installation"
echo "============================="
echo ""

# Ensure virtual display is running
if ! pgrep -x Xvfb > /dev/null; then
    echo "🖥️  Starting virtual display..."
    Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
    sleep 2
fi

# Check if Mono is already installed
if [ -e "$WINEPREFIX/drive_c/windows/mono" ]; then
    echo "✅ Mono already installed"
    exit 0
fi

# Test Wine first
echo "🧪 Testing Wine..."
if ! DISPLAY=:99 wine --version >/dev/null 2>&1; then
    echo "❌ Wine not working. Initializing..."
    DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wineboot --init >/dev/null 2>&1 || true
    sleep 3
fi

echo "✅ Wine is working: $(DISPLAY=:99 wine --version 2>&1)"
echo ""

# Download Mono
echo "📥 Downloading Mono..."
curl -o /tmp/mono.msi "$MONO_URL"

# Install Mono with verbose output
echo "📦 Installing Mono (this will take 5-10 minutes)..."
echo "   Please wait, this is a large installation..."
echo ""

# Try installation with different methods
DISPLAY=:99 WINEDLLOVERRIDES=mscoree=d wine msiexec /i /tmp/mono.msi /qn 2>&1 | tee /tmp/mono_install.log &
INSTALL_PID=$!

# Wait and monitor
echo "   Installation started (PID: $INSTALL_PID)"
echo "   Monitoring progress..."

for i in {1..60}; do
    sleep 10
    if [ -e "$WINEPREFIX/drive_c/windows/mono" ]; then
        echo ""
        echo "✅ Mono installation completed!"
        kill $INSTALL_PID 2>/dev/null || true
        break
    fi
    if ! ps -p $INSTALL_PID > /dev/null 2>&1; then
        echo ""
        echo "⚠️  Installation process ended"
        break
    fi
    echo -n "."
done

echo ""

# Check result
if [ -e "$WINEPREFIX/drive_c/windows/mono" ]; then
    MONO_SIZE=$(du -sh "$WINEPREFIX/drive_c/windows/mono" 2>/dev/null | cut -f1)
    echo "✅ Mono installed successfully!"
    echo "   Location: $WINEPREFIX/drive_c/windows/mono"
    echo "   Size: $MONO_SIZE"
    rm -f /tmp/mono.msi
    exit 0
else
    echo "❌ Mono installation failed"
    echo ""
    echo "📋 Troubleshooting:"
    echo "   1. Check installation log: cat /tmp/mono_install.log"
    echo "   2. Check Wine prefix: ls -la $WINEPREFIX/drive_c/windows/"
    echo "   3. Try manual installation:"
    echo "      DISPLAY=:99 WINEDLLOVERRIDES=mscoree=d wine msiexec /i /tmp/mono.msi"
    echo ""
    exit 1
fi



