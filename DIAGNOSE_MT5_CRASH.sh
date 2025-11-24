#!/bin/bash
# Diagnose why MT5 Terminal keeps crashing

set -e

echo "🔍 Diagnosing MT5 Terminal Crashes"
echo "=================================="
echo ""

export DISPLAY=:99
export WINEPREFIX="$HOME/.wine"

# Check Xvfb
echo "[1/6] Checking Xvfb (virtual display)..."
if pgrep -f "Xvfb :99" > /dev/null; then
    echo "✅ Xvfb is running"
    ps aux | grep "Xvfb :99" | grep -v grep
else
    echo "❌ Xvfb is NOT running!"
    echo "   Starting Xvfb..."
    Xvfb :99 -screen 0 1024x768x24 >/dev/null 2>&1 &
    sleep 2
    if pgrep -f "Xvfb :99" > /dev/null; then
        echo "   ✅ Xvfb started"
    else
        echo "   ❌ Failed to start Xvfb"
    fi
fi

echo ""

# Check Wine
echo "[2/6] Checking Wine..."
if command -v wine > /dev/null; then
    echo "✅ Wine is installed: $(wine --version)"
else
    echo "❌ Wine is not installed!"
    exit 1
fi

# Test Wine
echo "   Testing Wine..."
DISPLAY=:99 wine --version >/dev/null 2>&1 && echo "   ✅ Wine works with DISPLAY=:99" || echo "   ⚠️  Wine may have issues with DISPLAY=:99"

echo ""

# Check MT5 Terminal executable
echo "[3/6] Checking MT5 Terminal..."
MT5_EXE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
if [ -f "$MT5_EXE" ]; then
    echo "✅ MT5 Terminal found: $MT5_EXE"
    ls -lh "$MT5_EXE"
else
    echo "❌ MT5 Terminal not found: $MT5_EXE"
    exit 1
fi

echo ""

# Check Wine prefix
echo "[4/6] Checking Wine prefix..."
if [ -d "$WINEPREFIX" ]; then
    echo "✅ Wine prefix exists: $WINEPREFIX"
    echo "   Size: $(du -sh $WINEPREFIX 2>/dev/null | cut -f1)"
else
    echo "❌ Wine prefix not found: $WINEPREFIX"
    exit 1
fi

echo ""

# Try to start MT5 with verbose output
echo "[5/6] Attempting to start MT5 Terminal with verbose logging..."
echo "   (This will show what's causing the crash)"
echo ""

# Kill any existing MT5 processes
pkill -f "terminal64.exe\|terminal.exe" 2>/dev/null || true
sleep 2

# Start MT5 with logging
LOG_FILE="/tmp/mt5_startup.log"
echo "   Starting MT5 Terminal (logs: $LOG_FILE)..."
DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine "$MT5_EXE" > "$LOG_FILE" 2>&1 &
MT5_PID=$!

echo "   MT5 PID: $MT5_PID"
echo "   Waiting 10 seconds to see if it stays alive..."
sleep 10

if ps -p $MT5_PID > /dev/null 2>&1; then
    echo "   ✅ MT5 Terminal is still running after 10 seconds!"
    echo "   Process info:"
    ps aux | grep $MT5_PID | grep -v grep
else
    echo "   ❌ MT5 Terminal crashed!"
    echo ""
    echo "   Last 50 lines of log:"
    echo "   ====================="
    tail -50 "$LOG_FILE" | sed 's/^/   /'
    echo ""
    echo "   Full log available at: $LOG_FILE"
fi

echo ""

# Check for common issues
echo "[6/6] Checking for common issues..."
echo ""

# Check if Mono is installed
if [ -d "$WINEPREFIX/drive_c/Program Files/Mono" ]; then
    echo "✅ Mono is installed"
else
    echo "⚠️  Mono may not be installed (needed for MT5)"
fi

# Check disk space
DISK_SPACE=$(df -h "$WINEPREFIX" | tail -1 | awk '{print $4}')
echo "   Disk space: $DISK_SPACE available"

# Check memory
MEM_AVAIL=$(free -m | awk 'NR==2{printf "%.1f", $7}')
echo "   Available memory: ${MEM_AVAIL}MB"

# Check for Wine errors in dmesg
echo ""
echo "   Recent Wine errors (if any):"
dmesg | tail -20 | grep -i wine | tail -5 || echo "   (none found)"

echo ""
echo "✅ Diagnosis complete!"
echo ""
echo "📋 Summary:"
if ps -p $MT5_PID > /dev/null 2>&1; then
    echo "   ✅ MT5 Terminal is running (PID: $MT5_PID)"
    echo ""
    echo "   Next steps:"
    echo "   1. Wait 30-60 seconds for MT5 to fully initialize"
    echo "   2. Run: ./WAIT_AND_LOGIN.sh"
else
    echo "   ❌ MT5 Terminal is crashing"
    echo ""
    echo "   Check the log file: $LOG_FILE"
    echo "   Common fixes:"
    echo "   1. Reinstall Wine prefix: rm -rf ~/.wine && wineboot"
    echo "   2. Reinstall MT5 Terminal"
    echo "   3. Check Wine logs: wine --version"
    echo "   4. Try running MT5 with: DISPLAY=:99 wine '$MT5_EXE'"
fi

