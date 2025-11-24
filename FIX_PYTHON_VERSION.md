# Fix: Python Version Compatibility Issue

## ❌ Error

```
ERROR: Could not find a version that satisfies the requirement numpy==1.21.4 (from mt5linux)
ERROR: Ignored the following versions that require a different python version: 1.21.2 Requires-Python >=3.7,<3.11
```

## 🔍 Problem

- Your VPS is running **Python 3.12**
- `mt5linux` requires `numpy==1.21.4`
- `numpy 1.21.4` only supports Python **<3.11**
- **Incompatible!**

## ✅ Solutions

### Option 1: Use Python 3.10 or 3.11 (Recommended)

```bash
# Install Python 3.11
apt install -y python3.11 python3.11-venv python3.11-dev

# Remove old venv
rm -rf venv

# Create new venv with Python 3.11
python3.11 -m venv venv
source venv/bin/activate

# Verify Python version
python --version  # Should show 3.11.x

# Install requirements
pip install --upgrade pip
pip install -r requirements.txt
```

### Option 2: Install mt5linux with relaxed dependencies

```bash
# Install without strict dependency checking
pip install mt5linux --no-deps

# Then manually install compatible numpy
pip install "numpy>=1.21.0,<1.22.0"

# Install other mt5linux dependencies
pip install requests cryptography
```

### Option 3: Use MetaTrader5 via Wine (Alternative)

If mt5linux doesn't work, use the Windows MT5 via Wine:

```bash
# Install Wine
apt install -y wine64

# Install MetaTrader5 Python package (Windows version)
pip install MetaTrader5

# Then install MT5 Terminal via Wine
wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe
wine mt5setup.exe
```

## 🎯 Recommended: Use Python 3.11

The easiest solution is to use Python 3.11 instead of 3.12.

