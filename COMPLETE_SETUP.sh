#!/bin/bash
# Complete setup: Test connection, start API, configure Nginx, set up SSL

set -e

cd /opt/mt5-api-bridge
source venv/bin/activate

echo "🚀 Complete MT5 API Bridge Setup"
echo "=================================="
echo ""

# Step 1: Test MT5 Connection
echo "[1/5] Testing MT5 Connection..."
echo "================================"
export DISPLAY=:99
export WINEPREFIX="$HOME/.wine"

# Check if MT5 Terminal is running
if ! pgrep -f "terminal64.exe\|terminal.exe" > /dev/null; then
    echo "⚠️  MT5 Terminal is not running"
    echo "   Starting MT5 Terminal..."
    MT5FILE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
    DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine "$MT5FILE" >/dev/null 2>&1 &
    sleep 10
    echo "   ⚠️  Please log in to MT5 Terminal manually"
    echo "      Server: MetaQuotes-Demo"
    echo "      Login: 5042856355"
    echo "      Password: V!QzRxQ7"
    echo ""
    read -p "Press Enter after logging in to MT5 Terminal..."
fi

# Test connection
echo "🧪 Testing RPyC connection..."
python3 -c "
from mt5linux import MetaTrader5
try:
    mt5 = MetaTrader5(host='localhost', port=8001)
    account = mt5.account_info()
    if account:
        print(f'✅ Connection successful!')
        print(f'   Account: {account.login}')
        print(f'   Server: {account.server}')
        print(f'   Balance: {account.balance}')
    else:
        print('⚠️  Connected but account_info() returned None')
        print('   MT5 Terminal may not be logged in yet')
except Exception as e:
    print(f'❌ Connection failed: {e}')
    exit(1)
" || {
    echo "⚠️  Connection test failed - MT5 Terminal may need to be logged in"
    echo "   Continuing anyway..."
}

# Step 2: Start API Service
echo ""
echo "[2/5] Starting API Service..."
echo "============================"
systemctl start mt5-api
sleep 3

if systemctl is-active --quiet mt5-api; then
    echo "✅ API service is running"
    echo "   Test: curl http://localhost:8001/health"
    curl -s http://localhost:8001/health | head -5 || echo "   API may still be starting..."
else
    echo "⚠️  API service failed to start"
    echo "   Check: systemctl status mt5-api"
    journalctl -u mt5-api -n 20 --no-pager
fi

# Step 3: Configure Nginx
echo ""
echo "[3/5] Configuring Nginx..."
echo "=========================="
if [ ! -f "/etc/nginx/sites-available/mt5-api" ]; then
    chmod +x NGINX_CONFIG.sh
    ./NGINX_CONFIG.sh
else
    echo "✅ Nginx already configured"
fi

# Step 4: Set up SSL
echo ""
echo "[4/5] Setting up SSL Certificate..."
echo "==================================="
if [ ! -f "/etc/letsencrypt/live/trade.trainflow.dev/fullchain.pem" ]; then
    chmod +x SETUP_SSL.sh
    ./SETUP_SSL.sh
else
    echo "✅ SSL certificate already exists"
fi

# Step 5: Final Status
echo ""
echo "[5/5] Final Status Check"
echo "======================="
echo ""
echo "📊 Service Status:"
echo "   RPyC Server: $(systemctl is-active mt5-rpyc 2>/dev/null && echo '✅ Running' || echo '❌ Not running')"
echo "   API Service: $(systemctl is-active mt5-api 2>/dev/null && echo '✅ Running' || echo '❌ Not running')"
echo "   Nginx: $(systemctl is-active nginx 2>/dev/null && echo '✅ Running' || echo '❌ Not running')"
echo ""
echo "🔌 Ports:"
ss -tlnp | grep -E ":(8001|80|443) " | awk '{print "   " $4}'
echo ""
echo "🌐 Test URLs:"
echo "   HTTP:  http://trade.trainflow.dev/health"
echo "   HTTPS: https://trade.trainflow.dev/health"
echo "   API Docs: https://trade.trainflow.dev/docs"
echo ""
echo "✅ Setup Complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Ensure MT5 Terminal is running and logged in"
echo "   2. Test API: curl https://trade.trainflow.dev/health"
echo "   3. View API docs: https://trade.trainflow.dev/docs"
echo ""



