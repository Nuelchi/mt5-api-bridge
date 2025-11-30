#!/bin/bash
# Check API server status and fix if needed

echo "🔍 Checking API Server Status"
echo "=============================="
echo ""

# Check if API is running
echo "[1/3] Checking API service status..."
echo "===================================="
if systemctl is-active --quiet mt5-api; then
    echo "✅ API service is running"
    systemctl status mt5-api --no-pager -l | head -20
else
    echo "❌ API service is NOT running"
    echo "   Starting API service..."
    sudo systemctl start mt5-api
    sleep 5
    if systemctl is-active --quiet mt5-api; then
        echo "✅ API service started"
    else
        echo "❌ Failed to start API service"
        echo "   Checking logs..."
        journalctl -u mt5-api -n 50 --no-pager | tail -30
    fi
fi
echo ""

# Check if API is listening on port
echo "[2/3] Checking if API is listening on port 8000..."
echo "=================================================="
if ss -tuln 2>/dev/null | grep -q ":8000"; then
    echo "✅ API is listening on port 8000"
    ss -tuln | grep ":8000"
elif netstat -tuln 2>/dev/null | grep -q ":8000"; then
    echo "✅ API is listening on port 8000"
    netstat -tuln | grep ":8000"
else
    echo "❌ API is NOT listening on port 8000"
    echo "   API may have crashed or not started properly"
fi
echo ""

# Test API locally
echo "[3/3] Testing API locally..."
echo "==========================="
if curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ API is responding locally"
    curl -s http://localhost:8000/health | head -5
else
    echo "❌ API is NOT responding locally"
    echo "   API may have crashed"
    echo "   Check logs: journalctl -u mt5-api -n 100 --no-pager"
fi
echo ""

echo "=================================="
if systemctl is-active --quiet mt5-api && curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ API is running and responding"
    echo ""
    echo "📋 If you still get 502 errors:"
    echo "   1. Check nginx config: sudo nginx -t"
    echo "   2. Reload nginx: sudo systemctl reload nginx"
    echo "   3. Check nginx error logs: sudo tail -50 /var/log/nginx/error.log"
else
    echo "❌ API needs to be fixed"
    echo ""
    echo "💡 Try:"
    echo "   1. Restart API: sudo systemctl restart mt5-api"
    echo "   2. Check logs: journalctl -u mt5-api -n 100 --no-pager"
    echo "   3. Check for errors in logs"
fi
echo ""
