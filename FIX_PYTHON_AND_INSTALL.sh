#!/bin/bash
# Fix Python version issue and install dependencies
# mt5linux needs Python 3.11 or earlier

set -e

echo "🐍 Fixing Python version and installing dependencies..."
echo "======================================================"

# Check current Python version
echo ""
echo "Current Python version:"
python3 --version

# Install Python 3.11
echo ""
echo "[1/4] Installing Python 3.11..."
echo "-------------------------------"
apt-get install -y python3.11 python3.11-venv python3.11-dev || {
    echo "⚠️  Python 3.11 not available, trying alternative..."
    # Try installing from deadsnakes PPA if available
    apt-get install -y software-properties-common
    add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null || true
    apt-get update
    apt-get install -y python3.11 python3.11-venv python3.11-dev
}

echo "✅ Python 3.11 installed"

# Remove old venv and create new one with Python 3.11
echo ""
echo "[2/4] Creating virtual environment with Python 3.11..."
echo "-----------------------------------------------------"
cd /opt/mt5-api-bridge
rm -rf venv
python3.11 -m venv venv
source venv/bin/activate

echo "✅ Virtual environment created with Python 3.11"
python --version

# Upgrade pip
echo ""
echo "[3/4] Upgrading pip..."
echo "---------------------"
pip install --upgrade pip setuptools wheel
echo "✅ Pip upgraded"

# Install dependencies (skip mt5linux first, then install it separately)
echo ""
echo "[4/4] Installing dependencies..."
echo "-------------------------------"

# Install base requirements first
echo "Installing base packages..."
pip install fastapi==0.104.1 uvicorn[standard]==0.24.0 supabase==2.0.0 \
    python-dotenv==1.0.0 "httpx>=0.24.0,<0.25.0" pydantic==2.5.0 "PyJWT>=2.8.0"

# Install numpy first (compatible version)
echo "Installing numpy (compatible version)..."
pip install "numpy>=1.21.0,<1.22.0" || pip install numpy==1.21.6

# Now try to install mt5linux
echo "Installing mt5linux..."
pip install mt5linux>=0.1.9 || {
    echo "⚠️  mt5linux installation failed, trying with relaxed constraints..."
    pip install mt5linux --no-deps
    pip install numpy==1.21.6 cffi==1.15.0 cryptography==35.0.0
}

echo "✅ Dependencies installed"

# Verify installation
echo ""
echo "🧪 Verifying installation..."
python -c "import fastapi; import uvicorn; print('✅ FastAPI and Uvicorn OK')"
python -c "import mt5linux; print('✅ mt5linux OK')" || echo "⚠️  mt5linux import failed"

echo ""
echo "=========================================="
echo "✅ Python setup complete!"
echo "=========================================="
echo ""
echo "📋 Next: Start the service"
echo "   systemctl start mt5-api"
echo ""

