#!/bin/bash
# Alternative: Install mt5linux with relaxed dependencies or use MetaTrader5

set -e

echo "🔧 Alternative MT5 Installation"
echo "==============================="

cd /opt/mt5-api-bridge
source venv/bin/activate

echo ""
echo "Option 1: Try installing mt5linux with relaxed dependencies..."
echo "-------------------------------------------------------------"

# Try installing with --no-deps and manually install compatible packages
pip install --upgrade pip

# Install compatible numpy first
pip install "numpy>=1.21.0,<1.22.0" || pip install "numpy>=1.20.0,<1.22.0"

# Install mt5linux without strict dependency checking
pip install mt5linux --no-deps || {
    echo "⚠️  mt5linux installation failed"
    echo ""
    echo "Option 2: Using MetaTrader5 via Wine..."
    echo "----------------------------------------"
    
    # Install Wine
    apt install -y wine64 wine32
    
    # Install MetaTrader5 Python package (Windows version)
    pip install MetaTrader5
    
    echo "✅ MetaTrader5 Python package installed"
    echo "   You'll need to install MT5 Terminal via Wine separately"
    echo "   Download from: https://www.metatrader5.com/en/download"
}

echo ""
echo "✅ MT5 installation attempt complete"
echo "   Test with: python3 test_mt5_connection.py"
echo ""



