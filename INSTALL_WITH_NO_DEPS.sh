#!/bin/bash
# Alternative: Install mt5linux with --no-deps and manually install dependencies
# Use this if Python 3.10 installation fails

set -e

cd /opt/mt5-api-bridge

echo "🔧 Installing with --no-deps approach"
echo "===================================="

# Make sure venv is activated
if [ -z "$VIRTUAL_ENV" ]; then
    if [ -d "venv" ]; then
        source venv/bin/activate
    else
        echo "❌ No virtual environment found. Create one first."
        exit 1
    fi
fi

echo "✅ Python: $(python --version)"
echo "✅ Pip: $(which pip)"
echo ""

# Upgrade pip
pip install --upgrade pip

# Install base packages first
echo "📦 Installing base packages..."
pip install fastapi==0.104.1
pip install "uvicorn[standard]==0.24.0"
pip install supabase==2.0.0
pip install python-dotenv==1.0.0
pip install "httpx>=0.24.0,<0.25.0"
pip install pydantic==2.5.0

# Install numpy compatible with current Python version
echo ""
echo "📦 Installing compatible numpy..."
PYTHON_VERSION=$(python --version | cut -d' ' -f2 | cut -d'.' -f1,2)

if [ "$PYTHON_VERSION" = "3.10" ]; then
    pip install "numpy==1.21.4"
elif [ "$PYTHON_VERSION" = "3.11" ]; then
    echo "⚠️  Python 3.11 detected - numpy 1.21.4 not compatible"
    echo "   Installing numpy 1.21.1 (last compatible version)..."
    pip install "numpy==1.21.1" || pip install "numpy>=1.21.0,<1.22.0"
elif [ "$PYTHON_VERSION" = "3.12" ]; then
    echo "⚠️  Python 3.12 detected - installing latest compatible numpy..."
    pip install "numpy>=1.24.0"
else
    pip install "numpy>=1.21.0,<1.22.0"
fi

# Install mt5linux dependencies manually
echo ""
echo "📦 Installing mt5linux dependencies..."
pip install bleach==4.1.0 || pip install "bleach>=4.0.0"
pip install "cffi==1.15.0" || pip install "cffi>=1.15.0"
pip install "charset-normalizer==2.0.7" || pip install "charset-normalizer>=2.0.0"
pip install colorama==0.4.4 || pip install colorama
pip install "cryptography==35.0.0" || pip install "cryptography>=35.0.0"
pip install docutils==0.18 || pip install docutils
pip install "importlib-metadata==4.8.1" || pip install "importlib-metadata>=4.8.0"
pip install jeepney==0.7.1 || pip install jeepney
pip install "keyring==23.2.1" || pip install keyring
pip install requests || true
pip install urllib3 || true

# Install mt5linux without dependencies
echo ""
echo "📦 Installing mt5linux (no-deps)..."
pip install mt5linux --no-deps

echo ""
echo "✅ Installation complete!"
echo "   Python: $(python --version)"
echo "   Test MT5: python3 test_mt5_connection.py"
echo ""

