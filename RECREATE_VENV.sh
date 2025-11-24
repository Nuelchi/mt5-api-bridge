#!/bin/bash
# Recreate virtual environment and install with relaxed dependencies

set -e

cd /opt/mt5-api-bridge

echo "🔧 Recreating virtual environment..."
echo "===================================="

# Check Python version
PYTHON_VERSION=$(python3 --version)
echo "📋 Current Python: $PYTHON_VERSION"

# Remove old venv if exists
rm -rf venv

# Create new venv with current Python (3.12)
echo "🐍 Creating virtual environment..."
python3 -m venv venv

# Activate venv
echo "✅ Activating virtual environment..."
source venv/bin/activate

# Verify activation
echo "✅ Python in venv: $(python --version)"
echo "✅ Pip location: $(which pip)"

# Upgrade pip
echo "📦 Upgrading pip..."
pip install --upgrade pip

# Install base packages first
echo "📦 Installing base packages..."
pip install fastapi==0.104.1
pip install "uvicorn[standard]==0.24.0"
pip install supabase==2.0.0
pip install python-dotenv==1.0.0
pip install "httpx>=0.24.0,<0.25.0"
pip install pydantic==2.5.0

# Try installing mt5linux with relaxed approach
echo ""
echo "🔧 Installing MT5..."
echo "   Trying relaxed dependencies approach..."

# Install compatible numpy first
pip install "numpy>=1.21.0,<1.22.0" || {
    echo "⚠️  Could not install numpy 1.21.x, trying latest compatible..."
    pip install "numpy>=1.20.0,<1.23.0"
}

# Install mt5linux without strict dependencies
pip install mt5linux --no-deps || {
    echo "⚠️  mt5linux --no-deps failed, trying normal install..."
    pip install mt5linux || {
        echo "❌ mt5linux installation failed"
        echo ""
        echo "🔄 Alternative: Install MetaTrader5 (Windows version)..."
        pip install MetaTrader5
        echo "✅ MetaTrader5 installed (will need Wine + MT5 Terminal)"
    }
}

# Install other dependencies mt5linux might need
pip install requests cryptography keyring || true

echo ""
echo "✅ Installation complete!"
echo "   Python: $(python --version)"
echo "   Test with: python3 test_mt5_connection.py"
echo ""

