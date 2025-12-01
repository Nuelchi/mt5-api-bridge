#!/bin/bash
# Install Python 3.10 and recreate venv for mt5linux compatibility

set -e

echo "🐍 Installing Python 3.10 for mt5linux compatibility..."
echo "======================================================"

# Install Python 3.10
echo ""
echo "[1/4] Installing Python 3.10..."
echo "-------------------------------"
apt-get install -y software-properties-common
add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null || echo "PPA may already exist"
apt-get update
apt-get install -y python3.10 python3.10-venv python3.10-dev python3.10-distutils

echo "✅ Python 3.10 installed"

# Verify Python 3.10
python3.10 --version

# Remove old venv
echo ""
echo "[2/4] Removing old virtual environment..."
echo "----------------------------------------"
cd /opt/mt5-api-bridge
rm -rf venv

# Create new venv with Python 3.10
echo ""
echo "[3/4] Creating virtual environment with Python 3.10..."
echo "-----------------------------------------------------"
python3.10 -m venv venv
source venv/bin/activate

echo "✅ Virtual environment created"
python --version

# Upgrade pip
echo ""
echo "[4/4] Installing dependencies..."
echo "-------------------------------"
pip install --upgrade pip setuptools wheel

# Install dependencies
pip install -r requirements.txt

echo "✅ All dependencies installed successfully!"

# Verify mt5linux
echo ""
echo "🧪 Verifying installation..."
python -c "import mt5linux; print('✅ mt5linux imported successfully')" || echo "⚠️  mt5linux import failed"

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "📋 Next: Start the service"
echo "   systemctl start mt5-api"
echo ""

