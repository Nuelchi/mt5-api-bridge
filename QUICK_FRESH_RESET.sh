#!/bin/bash
# Quick Fresh Reset - Minimal cleanup and reinstall
# Use this if you just want to reset the service without removing everything

set -e

echo "🔄 Quick Fresh Reset for MT5 API Bridge"
echo ""

# Stop service
echo "[1/4] Stopping service..."
systemctl stop mt5-api 2>/dev/null || true

# Remove service file
echo "[2/4] Removing service..."
rm -f /etc/systemd/system/mt5-api.service
systemctl daemon-reload

# Recreate venv
echo "[3/4] Recreating Python environment..."
cd /opt/mt5-api-bridge
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Pull latest code
echo "[4/4] Pulling latest code..."
git pull

echo ""
echo "✅ Quick reset complete!"
echo ""
echo "📋 Next steps:"
echo "1. Check environment variables: cat /opt/mt5-api-bridge/.env"
echo "2. Run setup: ./COMPLETE_SETUP.sh"
echo "3. Or restart service: systemctl start mt5-api"
echo ""

