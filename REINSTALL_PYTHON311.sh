#!/bin/bash
# Reinstall with Python 3.11 for mt5linux compatibility

set -e

echo "🔧 Reinstalling with Python 3.11..."
echo "===================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (sudo bash REINSTALL_PYTHON311.sh)"
    exit 1
fi

cd /opt/mt5-api-bridge

# Install Python 3.11
echo "📦 Installing Python 3.11..."
apt install -y python3.11 python3.11-venv python3.11-dev python3.11-distutils

# Remove old venv
echo "🧹 Removing old virtual environment..."
rm -rf venv

# Create new venv with Python 3.11
echo "🐍 Creating new virtual environment with Python 3.11..."
python3.11 -m venv venv
source venv/bin/activate

# Verify Python version
echo "✅ Python version: $(python --version)"

# Upgrade pip
echo "📦 Upgrading pip..."
pip install --upgrade pip

# Install requirements
echo "📦 Installing requirements..."
pip install -r requirements.txt

echo ""
echo "✅ Reinstallation complete!"
echo "   Python version: $(python --version)"
echo "   Now you can continue with deployment"
echo ""

