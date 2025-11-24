# Quick Fix: Python 3.12 + mt5linux Compatibility

## 🎯 Simplest Solution (Try This First)

Since Python 3.11 isn't easily available, try installing mt5linux with relaxed dependencies:

```bash
cd /opt/mt5-api-bridge
source venv/bin/activate

# Install compatible numpy first
pip install "numpy>=1.21.0,<1.22.0"

# Install mt5linux without strict dependency checking
pip install mt5linux --no-deps

# Install other dependencies mt5linux might need
pip install requests cryptography keyring
```

## 🔄 If That Doesn't Work

### Option 1: Use MetaTrader5 (Windows version via Wine)

```bash
# Install Wine
apt install -y wine64

# Install MetaTrader5 Python package
pip install MetaTrader5

# Then install MT5 Terminal
wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe
wine mt5setup.exe
```

### Option 2: Build Python 3.11 from Source

```bash
# Install build dependencies
apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev \
    libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev

# Download and build Python 3.11
cd /tmp
wget https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz
tar -xzf Python-3.11.9.tgz
cd Python-3.11.9
./configure --enable-optimizations
make -j$(nproc)
make altinstall

# Create symlinks
ln -sf /usr/local/bin/python3.11 /usr/bin/python3.11
```

## ✅ Recommended: Try Relaxed Dependencies First

The easiest is to install mt5linux with `--no-deps` and manually install compatible packages.

