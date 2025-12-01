#!/bin/bash
# Setup Local Encryption Fallback for MT5 API Bridge

set -e

echo "🔐 Setting up Local Encryption Fallback"
echo "========================================"
echo ""

cd /opt/mt5-api-bridge

# Step 1: Install cryptography package
echo "[1/3] Installing cryptography package..."
source venv/bin/activate
pip install -q cryptography>=41.0.0
echo "✅ Cryptography installed"

# Step 2: Check if MT5_ENCRYPTION_KEY is already set
echo ""
echo "[2/3] Checking for MT5_ENCRYPTION_KEY..."

if grep -q "^MT5_ENCRYPTION_KEY=" .env 2>/dev/null; then
    echo "✅ MT5_ENCRYPTION_KEY already exists in .env"
    echo ""
    echo "Current value:"
    grep "^MT5_ENCRYPTION_KEY=" .env | sed 's/=.*/=***HIDDEN***/'
else
    echo "⚠️  MT5_ENCRYPTION_KEY not found in .env"
    echo ""
    echo "You need to add it manually:"
    echo "  1. Get the key from your backend environment (Render.com or .env file)"
    echo "  2. Add this line to .env:"
    echo "     MT5_ENCRYPTION_KEY=your_key_here"
    echo ""
    read -p "Do you have the encryption key ready? (y/n): " has_key
    
    if [ "$has_key" = "y" ] || [ "$has_key" = "Y" ]; then
        read -p "Enter MT5_ENCRYPTION_KEY: " encryption_key
        if [ -n "$encryption_key" ]; then
            echo "" >> .env
            echo "# Local encryption fallback (matches backend)" >> .env
            echo "MT5_ENCRYPTION_KEY=$encryption_key" >> .env
            echo "✅ Added MT5_ENCRYPTION_KEY to .env"
        fi
    fi
fi

# Step 3: Restart service
echo ""
echo "[3/3] Restarting MT5 API service..."
systemctl restart mt5-api
sleep 2

if systemctl is-active --quiet mt5-api; then
    echo "✅ Service restarted successfully"
else
    echo "❌ Service failed to start. Check logs: journalctl -u mt5-api -n 50"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "📋 Next steps:"
echo "   1. Test account connection:"
echo "      curl -X POST -H 'Authorization: Bearer \$JWT' ..."
echo ""
echo "   2. Check logs if issues:"
echo "      journalctl -u mt5-api -n 50 | grep -i encrypt"
echo ""

