#!/bin/bash
# Complete Deployment Script - Includes MT5 Terminal Installation
# Run this on your VPS

set -e

echo "🚀 MT5 API Bridge - Complete Deployment"
echo "======================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (sudo bash COMPLETE_DEPLOYMENT.sh)"
    exit 1
fi

# Step 1: Clean up
echo ""
echo "🧹 Step 1: Cleaning up old directories..."
rm -rf /opt/mt5-api-bridge /opt/MetaTrader5-Docker /opt/mt5 2>/dev/null || true
echo "✅ Cleanup done"

# Step 2: Update system
echo ""
echo "📦 Step 2: Updating system..."
apt update -qq
apt install -y python3 python3-pip python3-venv build-essential \
    libssl-dev libffi-dev python3-dev git curl nginx certbot \
    python3-certbot-nginx > /dev/null 2>&1
echo "✅ System updated"

# Step 3: Clone repository
echo ""
echo "📥 Step 3: Cloning repository..."
mkdir -p /opt/mt5-api-bridge
cd /opt/mt5-api-bridge
git clone https://github.com/Nuelchi/mt5-api-bridge.git . 2>/dev/null || git pull
echo "✅ Repository cloned"

# Step 4: Set up Python
echo ""
echo "🐍 Step 4: Setting up Python environment..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip -q
pip install -r requirements.txt -q
echo "✅ Python environment ready"

# Step 5: Install MT5
echo ""
echo "🔧 Step 5: Installing MT5..."
echo "   Installing mt5linux Python library..."
pip install mt5linux -q || {
    echo "   ⚠️  mt5linux install failed"
}

# Check if MT5 Terminal is needed
echo ""
echo "   Checking if MT5 Terminal is installed..."
if command -v mt5 &> /dev/null || [ -d "/opt/mt5" ] || [ -d "$HOME/.wine/drive_c/Program Files/MetaTrader 5" ]; then
    echo "   ✅ MT5 Terminal found"
else
    echo "   ⚠️  MT5 Terminal not found"
    echo ""
    read -p "   Do you want to install MT5 Terminal via Wine? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "   Installing Wine..."
        apt install -y wine64 wine32 > /dev/null 2>&1
        
        echo "   Downloading MT5 installer..."
        cd /tmp
        wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe || {
            echo "   ⚠️  Could not download MT5 installer"
            echo "   Please download manually from your broker"
        }
        
        echo "   Installing MT5 (this may take a few minutes)..."
        wine mt5setup.exe /S || {
            echo "   ⚠️  MT5 installation via Wine failed"
            echo "   You may need to install MT5 manually"
        }
        
        cd /opt/mt5-api-bridge
    else
        echo "   ⚠️  Skipping MT5 Terminal installation"
        echo "   You may need to install it manually later"
    fi
fi

# Step 6: Create .env
echo ""
echo "⚙️  Step 6: Creating .env file..."
cat > .env <<'EOF'
SUPABASE_URL=https://kgfzbkwyepchbysaysky.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtnZnpia3d5ZXBjaGJ5c2F5c2t5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Nzk5NDAsImV4cCI6MjA2ODA1NTk0MH0.WsMnjZsBPdM5okL4KZXZidX8eiTiGmN-Qc--Y359H6M
PORT=8001
HOST=0.0.0.0
CORS_ORIGINS=https://dashboard.trainflow.dev,https://traintrading.trainflow.dev,http://localhost:3000
DOMAIN=trade.trainflow.dev
LOG_LEVEL=INFO
EOF
echo "✅ .env file created"

# Step 7: Test MT5 connection
echo ""
echo "🧪 Step 7: Testing MT5 connection..."
python3 test_mt5_connection.py || {
    echo "   ⚠️  MT5 connection test failed"
    echo "   This is OK if MT5 Terminal is not installed yet"
    echo "   You can test again after installing MT5 Terminal"
}

# Step 8: Create systemd service
echo ""
echo "⚙️  Step 8: Creating systemd service..."
cat > /etc/systemd/system/mt5-api.service <<'EOF'
[Unit]
Description=MT5 API Bridge Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mt5-api-bridge
Environment="PATH=/opt/mt5-api-bridge/venv/bin"
ExecStart=/opt/mt5-api-bridge/venv/bin/uvicorn mt5_api_bridge:app --host 0.0.0.0 --port 8001
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mt5-api
systemctl start mt5-api
sleep 2

if systemctl is-active --quiet mt5-api; then
    echo "✅ Service is running!"
else
    echo "❌ Service failed - check: journalctl -u mt5-api"
fi

# Step 9: Test
echo ""
echo "🧪 Step 9: Testing API..."
sleep 1
curl -s http://localhost:8001/health | head -20 || echo "⚠️  API not responding"

echo ""
echo "=" * 60
echo "✅ Deployment Complete!"
echo "=" * 60
echo ""
echo "📋 Next Steps:"
echo "   1. If MT5 Terminal not installed, install it now"
echo "   2. Test MT5 connection: python3 test_mt5_connection.py"
echo "   3. Check service: systemctl status mt5-api"
echo "   4. View logs: journalctl -u mt5-api -f"
echo "   5. Configure Nginx: ./deploy_vps.sh"
echo ""

