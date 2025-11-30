#!/bin/bash
# Explicitly initialize MT5 via RPyC

echo "🔧 Initializing MT5 via RPyC"
echo "============================"
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

echo "📊 Testing MT5 initialization via RPyC..."
python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

try:
    print("   🔌 Connecting to RPyC server...")
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ RPyC connection established")
    
    print("   🔄 Attempting to initialize MT5...")
    # Try to initialize explicitly
    initialized = mt5.initialize()
    print(f"   Initialize result: {initialized}")
    
    if not initialized:
        error = mt5.last_error()
        print(f"   ❌ MT5 initialization failed!")
        print(f"   Error: {error}")
        print("")
        print("   This usually means:")
        print("   1. MT5 Terminal is not running")
        print("   2. MT5 Terminal is not accessible from Wine environment")
        print("   3. MT5 Terminal needs to be restarted")
        sys.exit(1)
    
    print("   ✅ MT5 initialized successfully")
    print("   ⏳ Waiting 5 seconds...")
    time.sleep(5)
    
    print("   📊 Getting terminal info...")
    terminal_info = mt5.terminal_info()
    if terminal_info:
        print(f"   ✅ Terminal info retrieved!")
        print(f"      Version: {terminal_info.build}")
        print(f"      Company: {terminal_info.company}")
        print(f"      Path: {terminal_info.path}")
        
        account = mt5.account_info()
        if account:
            print(f"      ✅ Account: {account.login} @ {account.server}")
            print(f"      Balance: {account.balance}")
        else:
            print(f"      ⚠️  Not logged in")
        
        sys.exit(0)
    else:
        print("   ❌ terminal_info() still returns None after initialization")
        print("   This is unusual - initialization succeeded but info is None")
        sys.exit(1)
        
except Exception as e:
    print(f"   ❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

TEST_RESULT=$?

echo ""
echo "==========================="
if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ MT5 Successfully Initialized and Accessible!"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Test API: curl -X GET 'https://trade.trainflow.dev/api/v1/account/info' -H 'Authorization: Bearer YOUR_TOKEN'"
    echo "   2. If not logged in, log in via API"
else
    echo "❌ MT5 Initialization Failed"
    echo ""
    echo "📋 The issue is that RPyC (Python inside Wine) cannot access MT5 Terminal."
    echo ""
    echo "📋 Possible Solutions:"
    echo ""
    echo "Option 1: Restart both MT5 Terminal and RPyC server"
    echo "   ./RESTART_MT5_AND_API.sh"
    echo ""
    echo "Option 2: Check if MT5 Terminal is actually running and accessible"
    echo "   The MT5 process exists but RPyC can't see it"
    echo ""
    echo "Option 3: Use MetaAPI instead (recommended for production)"
    echo "   MetaAPI is cloud-based and doesn't require Wine/MT5 Terminal"
    echo "   Your backend already has MetaAPI integration"
    echo ""
    echo "Option 4: Check MT5 Terminal logs for errors"
    echo "   screen -r mt5_terminal"
    echo "   (Press Ctrl+A then D to detach)"
fi
echo ""

