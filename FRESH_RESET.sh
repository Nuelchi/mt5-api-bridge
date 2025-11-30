#!/bin/bash
# Fresh Reset Script for MT5 API Bridge VPS
# This script completely removes and reinstalls everything from scratch

set -e  # Exit on error

echo "⚠️  WARNING: This will completely remove the MT5 API Bridge installation!"
echo "⚠️  All data, configurations, and services will be deleted!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Reset cancelled."
    exit 1
fi

echo ""
echo "🔄 Starting fresh reset..."
echo ""

# Step 1: Stop all services
echo "[1/8] Stopping services..."
systemctl stop mt5-api 2>/dev/null || true
systemctl disable mt5-api 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true
docker stop mt5 2>/dev/null || true
docker rm mt5 2>/dev/null || true

# Step 2: Remove systemd service
echo "[2/8] Removing systemd service..."
rm -f /etc/systemd/system/mt5-api.service
systemctl daemon-reload

# Step 3: Remove old installation
echo "[3/8] Removing old installation..."
if [ -d "/opt/mt5-api-bridge" ]; then
    rm -rf /opt/mt5-api-bridge
    echo "   ✅ Removed /opt/mt5-api-bridge"
fi

# Step 4: Remove Docker container and images (optional - uncomment if needed)
# echo "[4/8] Removing Docker containers..."
# docker stop mt5 2>/dev/null || true
# docker rm mt5 2>/dev/null || true
# docker rmi mt5-wine 2>/dev/null || true

# Step 5: Clean up Python virtual environments
echo "[4/8] Cleaning up Python environments..."
rm -rf /opt/mt5-api-bridge/venv 2>/dev/null || true
rm -rf ~/.cache/pip 2>/dev/null || true

# Step 6: Remove log files
echo "[5/8] Cleaning up logs..."
rm -rf /var/log/mt5-api 2>/dev/null || true
journalctl --vacuum-time=1d 2>/dev/null || true

# Step 7: Recreate directory
echo "[6/8] Creating fresh directory..."
mkdir -p /opt/mt5-api-bridge
cd /opt/mt5-api-bridge

# Step 8: Clone repository
echo "[7/8] Cloning repository..."
if [ -d ".git" ]; then
    echo "   Repository already exists, pulling latest..."
    git pull
else
    echo "   Cloning repository..."
    # Update with your actual repo URL
    git clone https://github.com/Nuelchi/mt5-api-bridge.git /tmp/mt5-api-bridge-temp
    cp -r /tmp/mt5-api-bridge-temp/* /opt/mt5-api-bridge/
    cp -r /tmp/mt5-api-bridge-temp/.* /opt/mt5-api-bridge/ 2>/dev/null || true
    rm -rf /tmp/mt5-api-bridge-temp
fi

# Step 9: Setup Python environment
echo "[8/8] Setting up Python environment..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo ""
echo "✅ Fresh reset complete!"
echo ""
echo "📋 Next steps:"
echo "1. Set up environment variables in /opt/mt5-api-bridge/.env"
echo "2. Run the setup script: ./COMPLETE_SETUP.sh"
echo "3. Or follow the deployment guide in README.md"
echo ""
echo "🔧 To configure environment variables:"
echo "   cd /opt/mt5-api-bridge"
echo "   nano .env"
echo ""
echo "📝 Required environment variables:"
echo "   - SUPABASE_URL"
echo "   - SUPABASE_SERVICE_ROLE_KEY"
echo "   - TRAINFLOW_BACKEND_URL"
echo "   - TRAINFLOW_SERVICE_KEY"
echo ""

