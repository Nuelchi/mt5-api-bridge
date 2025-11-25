#!/bin/bash
# Fix port 8001 conflict

set -e

echo "🔧 Fixing Port 8001 Conflict"
echo "============================"
echo ""

PORT=8001

# Check what's using port 8001
echo "🔍 Checking what's using port $PORT..."
PROCESS=$(ss -tlnp | grep ":$PORT " | awk '{print $6}' | cut -d',' -f2 | cut -d'=' -f2 || echo "none")

if [ "$PROCESS" != "none" ] && [ -n "$PROCESS" ]; then
    echo "⚠️  Port $PORT is in use by PID: $PROCESS"
    echo "   Process info:"
    ps -p $PROCESS -o pid,cmd --no-headers 2>/dev/null || echo "   Process not found"
    
    echo ""
    read -p "Kill the process using port $PORT? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kill $PROCESS 2>/dev/null || true
        sleep 2
        echo "✅ Process killed"
    fi
else
    echo "✅ Port $PORT is not in use"
fi

# Check all processes using port 8001
echo ""
echo "📋 All processes using port $PORT:"
ss -tlnp | grep ":$PORT " || echo "   None found"

# Stop mt5-rpyc service
echo ""
echo "🛑 Stopping mt5-rpyc service..."
systemctl stop mt5-rpyc 2>/dev/null || true
sleep 2

# Kill any remaining Python processes that might be mt5linux
echo ""
echo "🔍 Checking for mt5linux processes..."
MT5LINUX_PIDS=$(ps aux | grep "mt5linux" | grep -v grep | awk '{print $2}' || echo "")
if [ -n "$MT5LINUX_PIDS" ]; then
    echo "   Found mt5linux processes: $MT5LINUX_PIDS"
    for PID in $MT5LINUX_PIDS; do
        kill $PID 2>/dev/null || true
    done
    sleep 2
    echo "✅ Killed mt5linux processes"
fi

# Check port again
echo ""
echo "🔍 Final port check..."
if ss -tlnp | grep -q ":$PORT "; then
    echo "⚠️  Port $PORT is still in use:"
    ss -tlnp | grep ":$PORT "
    echo ""
    echo "   Try: killall python3 (if safe)"
else
    echo "✅ Port $PORT is now free"
fi

# Restart RPyC server
echo ""
echo "🔄 Restarting RPyC server..."
systemctl start mt5-rpyc
sleep 5

if systemctl is-active --quiet mt5-rpyc; then
    echo "✅ RPyC server started successfully!"
    echo "   Port: $(ss -tlnp | grep :8001 | awk '{print $4}' || echo '8001')"
else
    echo "❌ RPyC server still failing"
    echo ""
    echo "📋 Recent logs:"
    journalctl -u mt5-rpyc -n 15 --no-pager
fi

echo ""
echo "✅ Port conflict check complete!"
echo ""



