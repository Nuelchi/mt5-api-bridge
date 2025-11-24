#!/bin/bash
# Install Python 3.11 on Debian/Ubuntu

set -e

echo "🔧 Installing Python 3.11..."
echo "============================"

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

# For Debian/Ubuntu - add deadsnakes PPA
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    echo "📦 Adding deadsnakes PPA for Python 3.11..."
    
    # For Ubuntu
    if [ "$OS" = "ubuntu" ]; then
        apt install -y software-properties-common
        add-apt-repository -y ppa:deadsnakes/ppa
        apt update
    fi
    
    # For Debian - use backports or build from source
    if [ "$OS" = "debian" ]; then
        echo "📦 For Debian, we'll use alternative method..."
        # Try to enable backports
        echo "deb http://deb.debian.org/debian bullseye-backports main" >> /etc/apt/sources.list.d/backports.list
        apt update || true
    fi
    
    # Install Python 3.11
    apt install -y python3.11 python3.11-venv python3.11-dev python3.11-distutils || {
        echo "⚠️  Package installation failed, trying alternative..."
        
        # Alternative: Install from source (takes longer)
        echo "📦 Installing Python 3.11 from source..."
        apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev \
            libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev
        
        cd /tmp
        wget https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz
        tar -xzf Python-3.11.9.tgz
        cd Python-3.11.9
        ./configure --enable-optimizations
        make -j$(nproc)
        make altinstall
        
        # Create symlinks
        ln -sf /usr/local/bin/python3.11 /usr/bin/python3.11
        ln -sf /usr/local/bin/pip3.11 /usr/bin/pip3.11
        
        echo "✅ Python 3.11 installed from source"
    }
else
    echo "❌ Unsupported OS: $OS"
    exit 1
fi

echo ""
echo "✅ Python 3.11 installation complete!"
echo "   Verify with: python3.11 --version"
echo ""

