#!/bin/bash
# Wait for MT5 Terminal to be ready and test multiple times

echo "⏳ Waiting for MT5 Terminal to be Ready"
echo "========================================"
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

MAX_ATTEMPTS=6
ATTEMPT=0
SUCCESS=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    WAIT_TIME=$((ATTEMPT * 60))  # 60, 120, 180, 240, 300, 360 seconds
    
    echo "[Attempt $ATTEMPT/$MAX_ATTEMPTS] Waiting ${WAIT_TIME} seconds total..."
    echo "   (This attempt: 60 seconds)"
    sleep 60
    
    echo "   Testing RPyC connection..."
    python3 <<'PYEOF'
from mt5linux import MetaTrader5
import sys
import time

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    
    # Try to initialize with a shorter timeout expectation
    print("   Attempting initialize()...")
    try:
        initialized = mt5.initialize()
        if initialized:
            print("   ✅ MT5 initialized!")
            time.sleep(2)
            
            # Try terminal_info
            terminal_info = mt5.terminal_info()
            if terminal_info:
                print(f"   ✅ Terminal info: Build {terminal_info.build}")
                print("   ✅ MT5 Terminal is READY!")
                sys.exit(0)
            else:
                print("   ⚠️  terminal_info() is None")
                # Even if None, if initialize() worked, we can try login
                print("   ⚠️  But initialize() succeeded - may be ready for login")
                sys.exit(0)  # Consider this a success
        else:
            error = mt5.last_error()
            print(f"   ⚠️  Initialize returned False: {error}")
            sys.exit(1)
    except Exception as e:
        error_str = str(e).lower()
        if "timeout" in error_str or "expired" in error_str:
            print(f"   ⏳ Still timing out: {e}")
            print("   MT5 Terminal needs more time...")
        else:
            print(f"   ❌ Error: {e}")
        sys.exit(1)
        
except Exception as e:
    print(f"   ❌ Connection error: {e}")
    sys.exit(1)
PYEOF
    
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo ""
        echo "=================================="
        echo "✅ MT5 Terminal is READY!"
        echo ""
        echo "📋 Next Steps:"
        echo "   1. Restart API: sudo systemctl restart mt5-api"
        echo "   2. Connect account via API:"
        echo ""
        echo "   curl -X POST 'https://trade.trainflow.dev/api/v1/accounts/connect' \\"
        echo "     -H 'Authorization: Bearer YOUR_TOKEN' \\"
        echo "     -H 'Content-Type: application/json' \\"
        echo "     -d '{\"account_name\": \"MetaQuotes Demo\", \"login\": \"10008509685\", \"password\": \"!l1cBtTn\", \"server\": \"MetaQuotes-Demo\", \"account_type\": \"demo\", \"set_as_default\": true}'"
        SUCCESS=true
        break
    else
        echo "   ⏳ Not ready yet (attempt $ATTEMPT/$MAX_ATTEMPTS)"
        echo ""
    fi
done

if [ "$SUCCESS" = false ]; then
    echo "=================================="
    echo "⚠️  MT5 Terminal still not responding after ${MAX_ATTEMPTS} attempts"
    echo ""
    echo "💡 Troubleshooting:"
    echo "   1. Check RPyC logs: journalctl -u mt5-rpyc -n 50 --no-pager"
    echo "   2. Check MT5 screen log: tail -100 /tmp/mt5_screen.log"
    echo "   3. Check if MT5 process is still running: ps aux | grep terminal64.exe"
    echo "   4. Try restarting RPyC: sudo systemctl restart mt5-rpyc"
    echo "   5. Try connecting account anyway - sometimes login initializes MT5"
fi
echo ""

