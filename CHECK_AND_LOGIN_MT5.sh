#!/bin/bash
# Check if MT5 is logged in and log in if needed

echo "🔍 Checking MT5 Login Status"
echo "============================"
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

# Check if MT5 is accessible and logged in
python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

try:
    print("   Connecting to RPyC...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ Connected to RPyC")
    
    # Try to initialize
    print("   Initializing MT5...")
    if mt5.initialize():
        print("   ✅ MT5 initialized")
    else:
        error = mt5.last_error()
        print(f"   ⚠️  Initialize returned False: {error}")
    
    time.sleep(2)
    
    # Check if logged in
    print("   Checking login status...")
    account = mt5.account_info()
    
    if account:
        print(f"   ✅ MT5 is logged in!")
        print(f"      Account: {account.login}")
        print(f"      Server: {account.server}")
        print(f"      Balance: {account.balance}")
        print(f"      Equity: {account.equity}")
        sys.exit(0)
    else:
        print("   ⚠️  MT5 is NOT logged in")
        print("   terminal_info() check...")
        terminal_info = mt5.terminal_info()
        if terminal_info:
            print(f"   ✅ Terminal info available (Build: {terminal_info.build})")
            print("   But no account logged in")
        else:
            print("   ⚠️  terminal_info() also returns None")
            print("   MT5 Terminal may need more time to initialize")
        sys.exit(1)
        
except Exception as e:
    error_str = str(e).lower()
    if "timeout" in error_str or "expired" in error_str:
        print(f"   ⚠️  Timeout: {e}")
        print("   MT5 Terminal may still be initializing")
    else:
        print(f"   ❌ Error: {e}")
    sys.exit(1)
PYEOF

EXIT_CODE=$?

echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ MT5 is logged in and ready!"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Test API: curl -X GET 'https://trade.trainflow.dev/api/v1/account/info' -H 'Authorization: Bearer YOUR_TOKEN'"
else
    echo "⚠️  MT5 is not logged in"
    echo ""
    echo "💡 To log in:"
    echo "   1. Connect via VNC: vncserver :99"
    echo "   2. Open MT5 Terminal GUI"
    echo "   3. Log in to your account manually"
    echo ""
    echo "   OR use the API to connect an account:"
    echo "   curl -X POST 'https://trade.trainflow.dev/api/v1/accounts/connect' \\"
    echo "     -H 'Authorization: Bearer YOUR_TOKEN' \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"account_name\": \"...\", \"login\": \"...\", \"password\": \"...\", \"server\": \"...\"}'"
    echo ""
fi
