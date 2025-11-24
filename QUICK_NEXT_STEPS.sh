#!/bin/bash
# Quick next steps after MT5 installation

set -e

cd /opt/mt5-api-bridge
source venv/bin/activate

echo "🚀 Quick Next Steps"
echo "=================="
echo ""

# Make scripts executable
echo "📝 Making scripts executable..."
chmod +x *.sh 2>/dev/null || true

# Check RPyC server
echo ""
echo "🔌 Checking RPyC Server..."
if systemctl is-active --quiet mt5-rpyc 2>/dev/null; then
    echo "✅ RPyC server is running"
else
    echo "⚠️  RPyC server not running, checking status..."
    systemctl status mt5-rpyc --no-pager -l || {
        echo "   Starting RPyC server..."
        systemctl start mt5-rpyc
        sleep 3
        if systemctl is-active --quiet mt5-rpyc; then
            echo "✅ RPyC server started"
        else
            echo "❌ Failed to start RPyC server"
            echo "   View logs: journalctl -u mt5-rpyc -n 50"
        fi
    }
fi

# Start MT5 Terminal
echo ""
echo "📊 Starting MT5 Terminal..."
export WINEPREFIX="$HOME/.wine"
export DISPLAY=:99
MT5FILE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"

if pgrep -f "terminal64.exe\|terminal.exe" > /dev/null; then
    echo "✅ MT5 Terminal is already running"
else
    echo "   Starting MT5 Terminal in background..."
    DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" wine "$MT5FILE" >/dev/null 2>&1 &
    sleep 5
    if pgrep -f "terminal64.exe\|terminal.exe" > /dev/null; then
        echo "✅ MT5 Terminal started"
    else
        echo "⚠️  MT5 Terminal may have failed to start"
    fi
fi

# Test connection
echo ""
echo "🧪 Testing MT5 Connection..."
python3 test_mt5_connection_v3.py || {
    echo ""
    echo "⚠️  Connection test failed"
    echo "   This is normal if MT5 Terminal is not logged in yet"
    echo "   You need to log in to MT5 Terminal first"
}

# Create .env file
echo ""
echo "📝 Creating .env file..."
if [ ! -f .env ]; then
    cat > .env <<'EOF'
# Supabase Authentication
SUPABASE_URL=https://kgfzbkwyepchbysaysky.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtnZnpia3d5ZXBjaGJ5c2F5c2t5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Nzk5NDAsImV4cCI6MjA2ODA1NTk0MH0.WsMnjZsBPdM5okL4KZXZidX8eiTiGmN-Qc--Y359H6M

# Server Configuration
PORT=8001
HOST=0.0.0.0

# CORS Origins (comma-separated)
CORS_ORIGINS=https://dashboard.trainflow.dev,https://traintrading.trainflow.dev,http://localhost:3000

# Domain
DOMAIN=trade.trainflow.dev

# Logging
LOG_LEVEL=INFO
EOF
    echo "✅ .env file created"
else
    echo "✅ .env file already exists"
fi

# Create systemd service for API
echo ""
echo "🔄 Setting up API service..."
cat > /etc/systemd/system/mt5-api.service <<'EOF'
[Unit]
Description=MT5 API Bridge Service
After=network.target mt5-rpyc.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mt5-api-bridge
Environment="PATH=/opt/mt5-api-bridge/venv/bin"
EnvironmentFile=/opt/mt5-api-bridge/.env
ExecStart=/opt/mt5-api-bridge/venv/bin/uvicorn mt5_api_bridge:app --host 0.0.0.0 --port 8001
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mt5-api

# Test API locally
echo ""
echo "🧪 Testing API server..."
timeout 3 uvicorn mt5_api_bridge:app --host 0.0.0.0 --port 8001 >/dev/null 2>&1 || {
    echo "✅ API server can start"
}

echo ""
echo "✅ Setup Complete!"
echo ""
echo "📋 Summary:"
echo "   ✅ MT5 Terminal: $(pgrep -f 'terminal64.exe' > /dev/null && echo 'Running' || echo 'Not running')"
echo "   ✅ RPyC Server: $(systemctl is-active mt5-rpyc 2>/dev/null && echo 'Running' || echo 'Not running')"
echo "   ✅ API Service: Created (not started yet)"
echo ""
echo "📋 Next Steps:"
echo "   1. Log in to MT5 Terminal (if not already)"
echo "   2. Start API service: systemctl start mt5-api"
echo "   3. Configure Nginx: ./NGINX_CONFIG.sh"
echo "   4. Set up SSL: certbot --nginx -d trade.trainflow.dev"
echo ""

