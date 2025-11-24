# MT5 Linux Setup Guide

## How mt5linux Works

`mt5linux` uses **RPC (Remote Python Call)** to communicate with a running MT5 Terminal instance. This is different from the Windows `MetaTrader5` library which connects directly.

### Architecture:
```
Python API (mt5linux) → RPC Connection → MT5 Terminal (running on Linux)
```

### Requirements:
1. **MT5 Terminal** must be installed and running on Linux
2. **MT5 Terminal** must be logged in to your account
3. **RPC Server** must be running inside MT5 Terminal (via Expert Advisor or script)

## Installation Steps

### Option 1: Install MT5 Terminal via Wine (Recommended)

```bash
# Install Wine
apt update
apt install -y wine wine64

# Download MT5 Terminal installer
cd /tmp
wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe

# Install MT5 Terminal
wine mt5setup.exe

# MT5 Terminal will be installed in ~/.wine/drive_c/Program Files/MetaTrader 5/
```

### Option 2: Use Native Linux MT5 (if available)

Check if MetaQuotes provides a native Linux version.

## Starting MT5 Terminal

```bash
# Start MT5 Terminal
wine ~/.wine/drive_c/Program\ Files/MetaTrader\ 5/terminal64.exe

# Or create a script
cat > /opt/start_mt5.sh <<'EOF'
#!/bin/bash
cd ~/.wine/drive_c/Program\ Files/MetaTrader\ 5/
wine terminal64.exe
EOF
chmod +x /opt/start_mt5.sh
```

## Setting Up RPC Server in MT5

You need to install an Expert Advisor (EA) or script in MT5 that runs an RPC server.

### Option 1: Use mt5linux's built-in RPC server

The `mt5linux` package may include an RPC server script. Check:
```bash
python3 -c "import mt5linux; import os; print(os.path.dirname(mt5linux.__file__))"
```

### Option 2: Install RPC Server EA

1. Download an RPC server EA for MT5
2. Place it in `MQL5/Experts/` directory
3. Attach it to a chart
4. Configure the port (default is usually 18812)

## Testing Connection

Once MT5 Terminal is running and RPC server is active:

```python
from mt5linux import MetaTrader5

# Connect to RPC server (default: localhost:18812)
mt5 = MetaTrader5()  # Uses default host='localhost', port=18812

# Or specify custom host/port
mt5 = MetaTrader5(host='localhost', port=18812)

# Now you can use MT5 functions
account = mt5.account_info()
print(account)
```

## Troubleshooting

### Connection Refused Error
- **Cause**: MT5 Terminal is not running or RPC server is not active
- **Solution**: Start MT5 Terminal and ensure RPC server EA is running

### Port Already in Use
- **Cause**: Another instance is using the port
- **Solution**: Change the port in both MT5 RPC server and Python code

### Login Required
- **Cause**: MT5 Terminal is not logged in
- **Solution**: Log in to MT5 Terminal manually first, then the Python API can access it

