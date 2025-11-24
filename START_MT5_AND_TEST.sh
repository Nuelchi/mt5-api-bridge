#!/bin/bash
# Start MT5 Terminal and test connection

set -e

export WINEPREFIX="$HOME/.wine"
export DISPLAY=:99
MT5FILE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"

echo "🚀 Starting MT5 Terminal and Testing Connection"
echo "================================================"
echo ""

# Ensure virtual display is running
if ! pgrep -x Xvfb > /dev/null; then
    echo "🖥️  Starting virtual display..."
    Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
    sleep 2
fi

# Check if MT5 is already running
if pgrep -f "terminal64.exe\|terminal.exe" > /dev/null; then
    echo "✅ MT5 Terminal is already running"
else
    echo "📊 Starting MT5 Terminal..."
    DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine "$MT5FILE" >/dev/null 2>&1 &
    MT5_PID=$!
    echo "   MT5 Terminal started (PID: $MT5_PID)"
    echo "   Waiting 10 seconds for MT5 to initialize..."
    sleep 10
fi

# Check RPyC server
echo ""
echo "🔌 Checking RPyC Server..."
if systemctl is-active --quiet mt5-rpyc 2>/dev/null; then
    echo "✅ RPyC server is running"
elif ss -tlnp | grep -q ":8001"; then
    echo "✅ RPyC server is running on port 8001"
else
    echo "⚠️  RPyC server not running, starting it..."
    systemctl start mt5-rpyc 2>/dev/null || {
        echo "   Starting RPyC server manually..."
        cd /opt/mt5-api-bridge
        source venv/bin/activate
        python3 -m mt5linux --host 0.0.0.0 -p 8001 -w "DISPLAY=:99 wine" python.exe >/dev/null 2>&1 &
        sleep 3
    }
fi

# Test connection
echo ""
echo "🧪 Testing MT5 Connection..."
cd /opt/mt5-api-bridge
source venv/bin/activate

# Create a simple test
cat > /tmp/test_mt5_quick.py <<'EOF'
#!/usr/bin/env python3
from mt5linux import MetaTrader5
import sys

try:
    print("🔌 Connecting to MT5 via RPyC...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    
    print("📊 Testing connection...")
    account = mt5.account_info()
    
    if account:
        print(f"✅ Connection successful!")
        print(f"   Account: {account.login}")
        print(f"   Server: {account.server}")
        print(f"   Balance: {account.balance}")
        print(f"   Equity: {account.equity}")
        sys.exit(0)
    else:
        print("⚠️  Connected but account_info() returned None")
        print("   MT5 Terminal may not be logged in yet")
        sys.exit(1)
except ConnectionRefusedError:
    print("❌ Connection refused - RPyC server not running")
    print("   Start it with: systemctl start mt5-rpyc")
    sys.exit(1)
except Exception as e:
    print(f"❌ Connection error: {e}")
    sys.exit(1)
EOF

python3 /tmp/test_mt5_quick.py
TEST_RESULT=$?

echo ""
if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ MT5 Connection Test PASSED!"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Continue with API setup: ./NEXT_STEPS.sh"
    echo "   2. Configure Nginx: ./NGINX_CONFIG.sh"
    echo "   3. Set up SSL: certbot --nginx -d trade.trainflow.dev"
else
    echo "⚠️  Connection test failed"
    echo ""
    echo "📋 Troubleshooting:"
    echo "   1. Make sure MT5 Terminal is running and logged in"
    echo "   2. Check RPyC server: systemctl status mt5-rpyc"
    echo "   3. Check MT5 Terminal: ps aux | grep terminal"
    echo "   4. View RPyC logs: journalctl -u mt5-rpyc -f"
fi

rm -f /tmp/test_mt5_quick.py

