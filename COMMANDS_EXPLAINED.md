# Commands Explained - Step by Step

## 📋 What Each Command Does

### Step 1: SSH into VPS
```bash
ssh root@147.182.206.223
```
**What it does:** Connects you to your VPS server
**Result:** You're now logged into the VPS terminal

---

### Step 2: Clean Up Old Directories
```bash
rm -rf /opt/mt5-api-bridge /opt/MetaTrader5-Docker /opt/mt5
```
**What it does:** Deletes old/conflicting directories
- Removes any old MT5 API bridge installations
- Removes old MetaTrader5-Docker folder
- Removes any old MT5 installations
**Result:** Clean slate for fresh installation

---

### Step 3: Update System
```bash
apt update && apt upgrade -y
apt install -y python3 python3-pip python3-venv build-essential \
    libssl-dev libffi-dev python3-dev git curl nginx certbot \
    python3-certbot-nginx
```
**What it does:**
- `apt update` - Updates package list
- `apt upgrade -y` - Upgrades existing packages
- `apt install -y` - Installs required packages:
  - `python3` - Python interpreter
  - `python3-pip` - Python package manager
  - `python3-venv` - Virtual environment tool
  - `build-essential` - Compiler tools (needed for some Python packages)
  - `libssl-dev libffi-dev python3-dev` - Development libraries
  - `git` - Version control (to clone repo)
  - `curl` - HTTP client (for testing)
  - `nginx` - Web server (for reverse proxy/SSL)
  - `certbot python3-certbot-nginx` - SSL certificate tool
**Result:** System is ready with all dependencies

---

### Step 4: Clone Repository
```bash
cd /opt
git clone https://github.com/Nuelchi/mt5-api-bridge.git mt5-api-bridge
cd mt5-api-bridge
```
**What it does:**
- `cd /opt` - Goes to /opt directory (standard for applications)
- `git clone` - Downloads your code from GitHub
- `cd mt5-api-bridge` - Enters the project directory
**Result:** Your code is now on the VPS

---

### Step 5: Set Up Python Environment
```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install mt5linux
```
**What it does:**
- `python3 -m venv venv` - Creates isolated Python environment
- `source venv/bin/activate` - Activates the environment
- `pip install --upgrade pip` - Updates pip to latest version
- `pip install -r requirements.txt` - Installs Python packages:
  - FastAPI (web framework)
  - uvicorn (ASGI server)
  - supabase (authentication)
  - etc.
- `pip install mt5linux` - **Installs MT5 Python library**
**Result:** Python environment ready with all packages

**⚠️ IMPORTANT:** `pip install mt5linux` installs the **Python library** to talk to MT5, but you might also need the **MT5 Terminal** installed separately (see below)

---

### Step 6: Create .env File
```bash
cat > .env <<'EOF'
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
PORT=8001
...
EOF
```
**What it does:** Creates environment variables file
- Stores Supabase credentials
- Stores server configuration
- Stores CORS settings
**Result:** Configuration file ready

---

### Step 7: Test MT5 Connection
```bash
python3 test_mt5_connection.py
```
**What it does:** Tests if MT5 connection works
- Tries to connect to MT5 with your credentials
- Verifies login works
- Shows account information
**Result:** Confirms MT5 is accessible

---

### Step 8: Create Systemd Service
```bash
cat > /etc/systemd/system/mt5-api.service <<'EOF'
[Unit]
Description=MT5 API Bridge Service
...
EOF
systemctl daemon-reload
systemctl enable mt5-api
systemctl start mt5-api
```
**What it does:**
- Creates systemd service file (tells Linux how to run your app)
- `systemctl daemon-reload` - Reloads systemd configuration
- `systemctl enable mt5-api` - Makes service start on boot
- `systemctl start mt5-api` - Starts the service now
**Result:** Your API is now running as a background service

---

### Step 9: Verify
```bash
systemctl status mt5-api
curl http://localhost:8001/health
```
**What it does:**
- `systemctl status` - Shows if service is running
- `curl http://localhost:8001/health` - Tests if API responds
**Result:** Confirms everything is working

---

## 🔧 MT5 Installation - IMPORTANT!

### What `pip install mt5linux` Does

**Installs:** Python library to communicate with MT5
**Does NOT install:** The actual MT5 Terminal application

### You Might Need MT5 Terminal Too

The `mt5linux` library needs the MT5 Terminal to be installed. There are two options:

#### Option 1: mt5linux (Native Linux - Recommended)
```bash
pip install mt5linux
```
This might work standalone for some brokers, but typically needs MT5 Terminal.

#### Option 2: Install MT5 Terminal via Wine
If `mt5linux` doesn't work, you need to install the actual MT5 Terminal:

```bash
# Install Wine (Windows emulator)
apt install -y wine64

# Download MT5 installer
wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe

# Install MT5 via Wine
wine mt5setup.exe

# Or use your broker's MT5 installer
```

### Updated Deployment Steps

I'll create an updated script that handles MT5 Terminal installation too.

