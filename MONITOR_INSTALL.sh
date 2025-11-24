#!/bin/bash
# Monitor installation progress

export WINEPREFIX="$HOME/.wine"

echo "🔍 Monitoring Installation Progress"
echo "===================================="
echo ""

# Check if Mono installation is in progress
echo "📦 Mono Installation:"
if [ -e "$WINEPREFIX/drive_c/windows/mono" ]; then
    echo "   ✅ Mono installed"
    MONO_SIZE=$(du -sh "$WINEPREFIX/drive_c/windows/mono" 2>/dev/null | cut -f1)
    echo "   Size: $MONO_SIZE"
else
    echo "   ⏳ Mono still installing..."
    echo "   Check: ls -lh $WINEPREFIX/drive_c/windows/mono"
fi

# Check for installation processes
echo ""
echo "🔄 Running Processes:"
if pgrep -f "msiexec\|mt5setup\|python-installer" > /dev/null; then
    echo "   ⏳ Installation process detected:"
    ps aux | grep -E "msiexec|mt5setup|python-installer" | grep -v grep
else
    echo "   ✅ No installation processes running"
fi

# Check Wine processes
echo ""
echo "🍷 Wine Processes:"
WINE_PROCS=$(pgrep -f wine | wc -l)
if [ "$WINE_PROCS" -gt 0 ]; then
    echo "   ⏳ $WINE_PROCS Wine process(es) running"
    ps aux | grep wine | grep -v grep | head -3
else
    echo "   ✅ No Wine processes running"
fi

# Quick status check
echo ""
echo "📊 Quick Status:"
./CHECK_WINE_STATUS.sh 2>/dev/null | grep -E "✅|⚠️|❌" | head -10

echo ""
echo "💡 Tip: Wait for Mono installation to complete (5-10 minutes)"
echo "   Then run: ./CONTINUE_SETUP.sh"
echo ""

