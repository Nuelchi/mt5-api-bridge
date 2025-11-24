# Key Learnings from mt5-works Directory

## Overview

The `mt5-works` directory contains two important projects that show the **correct way** to run MT5 on Linux:

1. **MetaTrader5-Docker** - A complete Docker-based solution
2. **mt5linux** - The RPyC-based library source code

## Key Insights

### How mt5linux Actually Works

**Critical Understanding**: `mt5linux` does NOT directly connect to MT5 Terminal. Instead:

1. **Windows Python in Wine**: You need to install Python for Windows inside Wine
2. **Windows MetaTrader5 Library**: Install the Windows `MetaTrader5` library in that Windows Python
3. **RPyC Server**: Start an RPyC server that bridges Linux Python ↔ Windows Python
4. **Linux Client**: The `mt5linux` library on Linux makes RPC calls to the Windows Python

### Architecture

```
Linux Python (mt5linux) 
    ↓ RPyC (Remote Python Call)
Windows Python (in Wine) 
    ↓ Direct connection
MT5 Terminal (in Wine)
```

### What MetaTrader5-Docker Does

The Docker solution automates everything:

1. **Installs Wine** in Docker container
2. **Installs MT5 Terminal** via Wine
3. **Installs Windows Python** in Wine (`python-3.9.13.exe`)
4. **Installs Windows MetaTrader5 library** in Windows Python
5. **Starts RPyC server** using `python3 -m mt5linux --host 0.0.0.0 -p 8001 -w wine python.exe`
6. **Provides VNC access** via KasmVNC for GUI (optional)

### Key Files from MetaTrader5-Docker

**`start.sh`** shows the complete setup:
- Installs Mono for Wine
- Downloads and installs MT5 Terminal
- Installs Windows Python in Wine
- Installs `MetaTrader5==5.0.36` in Windows Python
- Installs `mt5linux` in both Windows and Linux Python
- Starts RPyC server: `python3 -m mt5linux --host 0.0.0.0 -p 8001 -w wine python.exe`

### What We Need to Do

Instead of trying to:
- ❌ Install MT5 Terminal directly on VPS
- ❌ Use `mt5linux` without RPyC server
- ❌ Connect directly to MT5 Terminal

We should:
- ✅ Install Windows Python in Wine
- ✅ Install Windows MetaTrader5 library in Windows Python
- ✅ Start RPyC server using `python3 -m mt5linux`
- ✅ Connect from our API using `MetaTrader5(host='localhost', port=8001)`

## Updated Approach

### Option 1: Use Docker (Recommended)

Use the MetaTrader5-Docker image directly:
```bash
docker run -d -p 3000:3000 -p 8001:8001 -v config:/config gmag11/metatrader5_vnc
```

Then connect from Python:
```python
from mt5linux import MetaTrader5
mt5 = MetaTrader5(host='localhost', port=8001)
mt5.initialize()
```

### Option 2: Manual Setup (What we were trying)

Follow the `start.sh` script approach:
1. Install Wine
2. Install MT5 Terminal in Wine
3. Install Windows Python in Wine
4. Install Windows MetaTrader5 library in Windows Python
5. Start RPyC server: `python3 -m mt5linux --host 0.0.0.0 -p 8001 -w wine python.exe`
6. Connect from API using `MetaTrader5(host='localhost', port=8001)`

## Key Commands from start.sh

```bash
# Install Windows Python in Wine
wine python-3.9.13.exe /quiet InstallAllUsers=1 PrependPath=1

# Install Windows MetaTrader5 library
wine python -m pip install MetaTrader5==5.0.36

# Install mt5linux in Windows Python
wine python -m pip install mt5linux>=0.1.9

# Start RPyC server
python3 -m mt5linux --host 0.0.0.0 -p 8001 -w wine python.exe
```

## Why Our Previous Approach Failed

We were trying to:
- Use `mt5linux` directly without the RPyC server
- Connect directly to MT5 Terminal (which doesn't work)

The correct flow is:
- Linux Python → RPyC → Windows Python → MT5 Terminal

## Next Steps

1. **Update our installation scripts** to follow the Docker approach
2. **Install Windows Python in Wine** (not just MT5 Terminal)
3. **Install Windows MetaTrader5 library** in Windows Python
4. **Start RPyC server** as a systemd service
5. **Update API bridge** to connect to RPyC server on localhost:8001

