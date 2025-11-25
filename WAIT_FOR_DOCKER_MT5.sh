#!/bin/bash
# Wait for Docker MT5 to be fully ready and test connection

set -e

echo "⏳ Waiting for Docker MT5 to be Ready"
echo "======================================"
echo ""

cd /opt/mt5-api-bridge
source venv/bin/activate

# Check if container is running
if ! docker ps | grep -q mt5; then
    echo "❌ MT5 Docker container is not running"
    echo "   Start it with: docker start mt5"
    exit 1
fi

echo "✅ Docker container is running"
echo ""

# Show container logs
echo "📋 Recent container logs:"
echo "=========================="
docker logs mt5 --tail 20
echo ""

# Wait for RPyC server to be ready
echo "⏳ Waiting for RPyC server to be ready..."
echo "=========================================="
echo "   This may take 2-5 minutes on first run"
echo "   (MT5 Terminal needs to install and start)"
echo ""

MAX_WAIT=300  # 5 minutes
WAITED=0
READY=false

while [ $WAITED -lt $MAX_WAIT ]; do
    # Check if port is open
    if timeout 2 bash -c "echo > /dev/tcp/localhost/8001" 2>/dev/null; then
        # Try to connect
        echo "   Testing connection... (${WAITED}s / ${MAX_WAIT}s)"
        
        python3 <<PYEOF
from mt5linux import MetaTrader5
import sys
import time

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    print("   ✅ Connected to RPyC server")
    
    # Try to initialize
    print("   Initializing MT5...")
    if mt5.initialize():
        print("   ✅ MT5 initialized!")
        sys.exit(0)
    else:
        error = mt5.last_error()
        print(f"   ⏳ Initialize returned False: {error}")
        print("   (MT5 may still be installing)")
        sys.exit(1)
        
except EOFError as e:
    print(f"   ⏳ Connection not ready yet: {e}")
    sys.exit(1)
except Exception as e:
    print(f"   ⏳ Error: {str(e)[:60]}")
    sys.exit(1)
PYEOF

        if [ $? -eq 0 ]; then
            READY=true
            break
        fi
    else
        echo "   ⏳ Port 8001 not responding yet... (${WAITED}s / ${MAX_WAIT}s)"
    fi
    
    WAITED=$((WAITED + 10))
    sleep 10
done

echo ""

if [ "$READY" = true ]; then
    echo "✅ SUCCESS! MT5 is ready!"
    echo ""
    echo "📋 Final Test:"
    echo "=============="
    python3 <<PYEOF
from mt5linux import MetaTrader5
import time

try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    mt5.initialize()
    
    # Try to get version
    try:
        version = mt5.version()
        print(f"   ✅ MT5 Version: {version}")
    except:
        print("   ⚠️  Could not get version")
    
    # Try terminal info
    try:
        terminal_info = mt5.terminal_info()
        if terminal_info:
            print(f"   ✅ Terminal Build: {terminal_info.build}")
        else:
            print("   ⚠️  Terminal info is None")
    except:
        print("   ⚠️  Could not get terminal info")
    
    print("")
    print("   ✅ MT5 Docker is working!")
    
except Exception as e:
    print(f"   ❌ Error: {e}")
PYEOF

    echo ""
    echo "🌐 Access MT5 Terminal GUI:"
    echo "   http://147.182.206.223:3000"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Access VNC to log in to MT5 (if needed)"
    echo "   2. Update .env file (already done by setup script)"
    echo "   3. Run: ./TEST_AND_SETUP.sh to complete API setup"
else
    echo "⚠️  MT5 did not become ready after ${MAX_WAIT} seconds"
    echo ""
    echo "💡 Check Docker logs:"
    echo "   docker logs mt5"
    echo ""
    echo "💡 The container may still be installing MT5 Terminal"
    echo "   This can take 5-10 minutes on first run"
    echo "   Check logs to see progress: docker logs -f mt5"
fi

echo ""

