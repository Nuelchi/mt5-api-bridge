#!/bin/bash
# VPS Setup Script - Complete Setup
# Run this on your VPS after cloning the repository

set -e

echo "🚀 MT5 API Bridge - VPS Setup"
echo "=============================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (sudo ./vps_setup_script.sh)"
    exit 1
fi

# Step 1: Clean up old directories
echo ""
echo "🧹 Step 1: Cleaning up old directories..."
echo "----------------------------------------"

# List common old MT5 directories
OLD_DIRS=(
    "/opt/mt5-api-bridge"
    "/opt/MetaTrader5-Docker"
    "/opt/mt5"
    "/home/mt5"
    "/var/www/mt5"
)

for dir in "${OLD_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "   Removing: $dir"
        rm -rf "$dir"
    fi
done

echo "✅ Cleanup complete"

# Step 2: Update system
echo ""
echo "📦 Step 2: Updating system packages..."
echo "--------------------------------------"
apt update && apt upgrade -y
apt install -y python3 python3-pip python3-venv build-essential \
    libssl-dev libffi-dev python3-dev git curl nginx certbot \
    python3-certbot-nginx

echo "✅ System updated"

# Step 3: Create application directory
echo ""
echo "📁 Step 3: Creating application directory..."
echo "-------------------------------------------"
APP_DIR="/opt/mt5-api-bridge"
mkdir -p $APP_DIR
cd $APP_DIR
echo "✅ Directory created: $APP_DIR"

# Step 4: Clone repository
echo ""
echo "📥 Step 4: Cloning repository from GitHub..."
echo "-------------------------------------------"
if [ -d ".git" ]; then
    echo "   Repository already cloned, pulling latest..."
    git pull
else
    git clone https://github.com/Nuelchi/mt5-api-bridge.git .
fi
echo "✅ Repository cloned"

# Step 5: Create virtual environment
echo ""
echo "🐍 Step 5: Creating Python virtual environment..."
echo "------------------------------------------------"
python3 -m venv venv
source venv/bin/activate
echo "✅ Virtual environment created"

# Step 6: Install Python packages
echo ""
echo "📦 Step 6: Installing Python packages..."
echo "---------------------------------------"
pip install --upgrade pip
pip install -r requirements.txt
echo "✅ Python packages installed"

# Step 7: Install MT5
echo ""
echo "🔧 Step 7: Installing MT5 (mt5linux)..."
echo "--------------------------------------"
pip install mt5linux || {
    echo "⚠️  mt5linux installation failed, trying alternative..."
    echo "   You may need to install MT5 via Wine instead"
}
echo "✅ MT5 installation attempted"

# Step 8: Create .env file
echo ""
echo "⚙️  Step 8: Setting up environment variables..."
echo "---------------------------------------------"
if [ ! -f ".env" ]; then
    cat > .env <<EOF
# Supabase Authentication
SUPABASE_URL=https://kgfzbkwyepchbysaysky.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtnZnpia3d5ZXBjaGJ5c2F5c2t5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Nzk5NDAsImV4cCI6MjA2ODA1NTk0MH0.WsMnjZsBPdM5okL4KZXZidX8eiTiGmN-Qc--Y359H6M

# Server Configuration
PORT=8001
HOST=0.0.0.0

# CORS
CORS_ORIGINS=https://dashboard.trainflow.dev,https://traintrading.trainflow.dev,http://localhost:3000

# Domain
DOMAIN=trade.trainflow.dev

# Logging
LOG_LEVEL=INFO
EOF
    echo "✅ .env file created"
else
    echo "⚠️  .env file already exists, skipping..."
fi

# Step 9: Test MT5 connection
echo ""
echo "🧪 Step 9: Testing MT5 connection..."
echo "----------------------------------"
python3 test_mt5_connection.py || {
    echo "⚠️  MT5 connection test failed"
    echo "   You may need to configure MT5 manually"
}

# Step 10: Create systemd service
echo ""
echo "⚙️  Step 10: Creating systemd service..."
echo "---------------------------------------"
cat > /etc/systemd/system/mt5-api.service <<EOF
[Unit]
Description=MT5 API Bridge Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
ExecStart=$APP_DIR/venv/bin/uvicorn mt5_api_bridge:app --host 0.0.0.0 --port 8001
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mt5-api
echo "✅ Systemd service created"

# Step 11: Start service
echo ""
echo "🚀 Step 11: Starting service..."
echo "-------------------------------"
systemctl start mt5-api
sleep 2

if systemctl is-active --quiet mt5-api; then
    echo "✅ Service is running!"
else
    echo "❌ Service failed to start. Check logs: journalctl -u mt5-api"
fi

# Summary
echo ""
echo "=" * 60
echo "✅ VPS Setup Complete!"
echo "=" * 60
echo ""
echo "📋 Next Steps:"
echo "   1. Test health endpoint: curl http://localhost:8001/health"
echo "   2. Check service status: systemctl status mt5-api"
echo "   3. View logs: journalctl -u mt5-api -f"
echo "   4. Configure Nginx (optional): ./deploy_vps.sh"
echo ""



