#!/bin/bash
# Verify MT5 Terminal, RPyC, and API are all working

echo "🔍 Verifying MT5 Setup"
echo "====================="
echo ""

# Check MT5 Terminal
echo "[1/4] Checking MT5 Terminal..."
if pgrep -f "terminal64.exe" > /dev/null; then
    echo "   ✅ MT5 Terminal is running"
    echo "   PIDs: $(pgrep -f terminal64.exe | tr '\n' ' ')"
else
    echo "   ❌ MT5 Terminal is NOT running"
    echo "   Start it with: sudo ./START_MT5_TERMINAL.sh"
fi
echo ""

# Check RPyC server
echo "[2/4] Checking RPyC server..."
if systemctl is-active --quiet mt5-rpyc; then
    echo "   ✅ RPyC server is running"
    RPYC_STATUS="running"
else
    echo "   ❌ RPyC server is NOT running"
    echo "   Start it with: sudo systemctl start mt5-rpyc"
    RPYC_STATUS="stopped"
fi
echo ""

# Check API server
echo "[3/4] Checking API server..."
if systemctl is-active --quiet mt5-api; then
    echo "   ✅ API server is running"
    API_STATUS="running"
else
    echo "   ❌ API server is NOT running"
    echo "   Start it with: sudo systemctl start mt5-api"
    API_STATUS="stopped"
fi
echo ""

# Test RPyC connection
echo "[4/4] Testing RPyC connection to MT5..."
if [ "$RPYC_STATUS" = "running" ]; then
    source venv/bin/activate 2>/dev/null || {
        echo "   ⚠️  Virtual environment not found, trying system Python..."
    }
    
    python3 <<PYEOF
from mt5linux import MetaTrader5
import sys

try:
    print("   Connecting to RPyC server (localhost:8001)...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    
    print("   Initializing MT5...")
    if mt5.initialize():
        print("   ✅ MT5 initialized successfully!")
        
        # Try to get terminal info
        terminal_info = mt5.terminal_info()
        if terminal_info:
            print(f"   Terminal: {terminal_info.name}")
            print(f"   Company: {terminal_info.company}")
            print(f"   Path: {terminal_info.path}")
        else:
            print("   ⚠️  terminal_info() returned None (MT5 may still be initializing)")
        
        # Try to get account info (if logged in)
        account_info = mt5.account_info()
        if account_info:
            print(f"   ✅ Account logged in: {account_info.login}")
            print(f"   Server: {account_info.server}")
            print(f"   Balance: {account_info.balance}")
        else:
            print("   ℹ️  No account logged in yet (this is OK)")
        
        sys.exit(0)
    else:
        error = mt5.last_error() if hasattr(mt5, 'last_error') else "Unknown error"
        print(f"   ❌ MT5 initialization failed: {error}")
        sys.exit(1)
        
except Exception as e:
    print(f"   ❌ Connection error: {e}")
    print("   This could mean:")
    print("      - RPyC server is not ready yet")
    print("      - MT5 Terminal is still initializing")
    print("      - Port 8001 is not accessible")
    sys.exit(1)
PYEOF
    
    TEST_RESULT=$?
    if [ $TEST_RESULT -eq 0 ]; then
        echo ""
        echo "✅ All checks passed! MT5 setup is working."
    else
        echo ""
        echo "⚠️  Connection test failed, but services are running."
        echo "   MT5 Terminal may still be initializing (wait 1-2 minutes)"
        echo "   Or check logs: journalctl -u mt5-rpyc -n 50"
    fi
else
    echo "   ⚠️  Skipping connection test (RPyC server not running)"
fi

echo ""
echo "📋 Summary:"
echo "   MT5 Terminal: $(pgrep -f terminal64.exe > /dev/null && echo '✅ Running' || echo '❌ Not running')"
echo "   RPyC Server: $(systemctl is-active --quiet mt5-rpyc && echo '✅ Running' || echo '❌ Not running')"
echo "   API Server: $(systemctl is-active --quiet mt5-api && echo '✅ Running' || echo '❌ Not running')"
echo ""
echo "📝 Next Steps:"
echo "   1. If MT5 is not logged in, access VNC: http://147.182.206.223:3000/vnc.html"
echo "   2. Log in to your MT5 account via VNC"
echo "   3. Test API: curl http://localhost:8000/health"
echo "   4. Connect account via API: curl -X POST 'https://trade.trainflow.dev/api/v1/accounts/connect' ..."
echo ""

