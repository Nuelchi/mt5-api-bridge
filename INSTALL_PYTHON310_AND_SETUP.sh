#!/bin/bash
# Install Python 3.10 and recreate venv with it (mt5linux requires Python <3.11)

set -e

cd /opt/mt5-api-bridge

echo "🔧 Installing Python 3.10 and Setting Up Environment"
echo "===================================================="

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "❌ Cannot detect OS"
    exit 1
fi

echo "📋 Detected OS: $OS $VERSION"
echo ""

# Check if Python 3.10 already exists
if command -v python3.10 &> /dev/null; then
    echo "✅ Python 3.10 already installed: $(python3.10 --version)"
else
    echo "📦 Installing Python 3.10..."
    
    # For Ubuntu
    if [ "$OS" = "ubuntu" ]; then
        apt install -y software-properties-common
        add-apt-repository -y ppa:deadsnakes/ppa
        apt update
        apt install -y python3.10 python3.10-venv python3.10-dev python3.10-distutils
        
    # For Debian - try backports first, then source
    elif [ "$OS" = "debian" ]; then
        echo "📦 Trying Debian backports..."
        echo "deb http://deb.debian.org/debian bullseye-backports main" > /etc/apt/sources.list.d/backports.list 2>/dev/null || true
        apt update || true
        
        apt install -y python3.10 python3.10-venv python3.10-dev python3.10-distutils || {
            echo "⚠️  Package installation failed, installing from source..."
            
            # Install from source
            apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev \
                libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev
            
            cd /tmp
            wget https://www.python.org/ftp/python/3.10.13/Python-3.10.13.tgz
            tar -xzf Python-3.10.13.tgz
            cd Python-3.10.13
            ./configure --enable-optimizations --prefix=/usr/local
            make -j$(nproc)
            make altinstall
            
            # Create symlinks
            ln -sf /usr/local/bin/python3.10 /usr/bin/python3.10 || true
            ln -sf /usr/local/bin/pip3.10 /usr/bin/pip3.10 || true
            
            cd /opt/mt5-api-bridge
        }
    else
        echo "❌ Unsupported OS: $OS"
        exit 1
    fi
    
    echo "✅ Python 3.10 installed: $(python3.10 --version)"
fi

echo ""
echo "🔧 Recreating virtual environment with Python 3.10..."
echo "===================================================="

# Remove old venv
rm -rf venv

# Create new venv with Python 3.10
python3.10 -m venv venv

# Activate venv
source venv/bin/activate

# Verify Python version
echo "✅ Python in venv: $(python --version)"
echo "✅ Pip location: $(which pip)"
echo ""

# Upgrade pip
echo "📦 Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt

echo ""
echo "✅ Setup complete!"
echo "   Python: $(python --version)"
echo "   Test MT5: python3 test_mt5_connection.py"
echo ""



