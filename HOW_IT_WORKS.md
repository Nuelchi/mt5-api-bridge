# How MT5 API Bridge Works - Complete Explanation

## 🤔 Your Question: Do I Need to Install MT5?

**Short Answer:** Yes, you need MT5 Terminal installed on your Linux VPS, BUT my code handles all the API communication.

## 🏗️ Architecture Breakdown

```
┌─────────────────────────────────────────────────────────────┐
│  Your Application (Cloud/Anywhere)                           │
│  - Makes HTTP requests to MT5 API Bridge                    │
│  - Sends JWT token for authentication                      │
└───────────────────────┬─────────────────────────────────────┘
                        │ HTTPS/WebSocket
                        │ (JWT Auth)
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Linux VPS (147.182.206.223)                                │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  MT5 API Bridge (My Code) - Port 8001               │   │
│  │  - FastAPI server                                    │   │
│  │  - Supabase JWT authentication                       │   │
│  │  - REST API endpoints                                │   │
│  │  - THIS IS WHAT I BUILT FOR YOU                      │   │
│  └──────────────┬───────────────────────────────────────┘   │
│                 │ Python library calls                      │
│                 ▼                                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  MT5 Python Library (mt5linux)                        │   │
│  │  - Python package: pip install mt5linux               │   │
│  │  - Communicates with MT5 Terminal                     │   │
│  └──────────────┬───────────────────────────────────────┘   │
│                 │ Native connection                          │
│                 ▼                                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  MetaTrader 5 Terminal (Linux)                       │   │
│  │  - YOU NEED TO INSTALL THIS                          │   │
│  │  - Running on the VPS                                │   │
│  │  - Connected to your broker                          │   │
│  │  - Account logged in                                 │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 📦 What You Need to Install on VPS

### 1. **MT5 Terminal** (Required)
   - **Option A: mt5linux** (Recommended - Native Linux)
     ```bash
     # Install mt5linux (native Linux MT5)
     pip install mt5linux
     ```
     - No Wine needed
     - Native Linux implementation
     - Easier to set up

   - **Option B: MetaTrader 5 via Wine** (Alternative)
     ```bash
     # Install Wine
     apt install wine64
     
     # Download MT5 installer
     wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe
     
     # Install via Wine
     wine mt5setup.exe
     ```
     - Requires Wine (Windows emulator)
     - More complex setup
     - Uses Windows MT5 terminal

### 2. **Python & Dependencies** (My Code Handles This)
   - Python 3.8+
   - FastAPI, uvicorn, supabase
   - **My deployment script installs these automatically**

### 3. **MT5 Account Connection** (You Do This Once)
   - Install MT5 Terminal
   - Log in with your broker credentials
   - Keep it running

## 🎯 What My Code Does vs What You Do

### ✅ What My Code Handles (Automatic)

1. **Web API Server**
   - Creates FastAPI server on port 8001
   - Handles HTTP requests
   - Manages authentication

2. **JWT Authentication**
   - Verifies Supabase JWT tokens
   - Extracts user information
   - Protects API endpoints

3. **MT5 Communication**
   - Uses Python MT5 library to talk to MT5 Terminal
   - Gets historical data
   - Executes trades
   - Manages positions

4. **API Endpoints**
   - `/api/v1/account/info` - Get account info
   - `/api/v1/market-data/{symbol}` - Get historical data
   - `/api/v1/trades` - Place orders
   - `/api/v1/positions` - Get positions
   - And more...

5. **Deployment**
   - Systemd service setup
   - Nginx configuration
   - SSL certificate setup
   - Auto-restart on failure

### 🔧 What You Need to Do (One-Time Setup)

1. **Install MT5 Terminal on VPS**
   ```bash
   # Option 1: mt5linux (easier)
   pip install mt5linux
   
   # Option 2: MT5 via Wine (if mt5linux doesn't work)
   # Follow Wine installation steps above
   ```

2. **Connect MT5 Account**
   - Open MT5 Terminal
   - Log in with your broker credentials
   - Keep terminal running

3. **Deploy My Code**
   ```bash
   # Upload files
   scp -r mt5-api-bridge/* root@147.182.206.223:/opt/mt5-api-bridge/
   
   # Run deployment script
   ./deploy_vps.sh
   ```

4. **Configure Environment**
   - Create `.env` file with Supabase credentials
   - (Already done - just copy `.env.production` to `.env`)

## 🔄 How It Works Step-by-Step

### Example: Getting Historical Data

1. **Your App Makes Request:**
   ```javascript
   fetch('https://trade.trainflow.dev/api/v1/market-data/EURUSD?timeframe=H1&bars=100', {
     headers: {
       'Authorization': 'Bearer YOUR_JWT_TOKEN'
     }
   })
   ```

2. **My API Bridge:**
   - Receives request
   - Verifies JWT token with Supabase ✅
   - Calls MT5 Python library: `mt5.copy_rates_from_pos('EURUSD', mt5.TIMEFRAME_H1, 0, 100)`

3. **MT5 Python Library:**
   - Communicates with MT5 Terminal
   - Gets data from terminal

4. **MT5 Terminal:**
   - Fetches data from broker
   - Returns to Python library

5. **Response:**
   - Python library → My API → Your App
   - Returns JSON with candle data

## 📋 Complete Setup Checklist

### On Your VPS:

- [ ] **Install MT5 Terminal**
  - [ ] Option A: `pip install mt5linux` (recommended)
  - [ ] Option B: Install MT5 via Wine (if needed)

- [ ] **Connect MT5 Account**
  - [ ] Open MT5 Terminal
  - [ ] Log in with broker credentials
  - [ ] Verify connection works
  - [ ] Keep terminal running

- [ ] **Deploy My Code**
  - [ ] Upload `mt5-api-bridge/` folder to VPS
  - [ ] Run `./deploy_vps.sh`
  - [ ] Create `.env` file with Supabase credentials

- [ ] **Test**
  - [ ] Test JWT authentication: `python3 test_jwt_auth.py`
  - [ ] Test health endpoint: `curl http://localhost:8001/health`
  - [ ] Test authenticated endpoint with your JWT token

## 🎯 Summary

**What I Built:**
- ✅ Web API server (FastAPI)
- ✅ JWT authentication (Supabase)
- ✅ MT5 Python integration
- ✅ REST API endpoints
- ✅ Deployment automation

**What You Need:**
- 🔧 MT5 Terminal installed on VPS (one-time)
- 🔧 MT5 account connected (one-time)
- 🔧 Deploy my code (one-time)

**What Happens Automatically:**
- ✅ API server runs 24/7
- ✅ Handles all HTTP requests
- ✅ Verifies JWT tokens
- ✅ Communicates with MT5
- ✅ Returns data to your app

## 🚀 Quick Start

1. **On VPS, install MT5:**
   ```bash
   pip install mt5linux
   ```

2. **Deploy my code:**
   ```bash
   scp -r mt5-api-bridge/* root@147.182.206.223:/opt/mt5-api-bridge/
   ssh root@147.182.206.223
   cd /opt/mt5-api-bridge
   ./deploy_vps.sh
   ```

3. **Connect MT5 account:**
   - Open MT5 Terminal
   - Log in
   - Keep running

4. **Done!** Your API is ready at `https://trade.trainflow.dev`

---

**Think of it like this:**
- **MT5 Terminal** = The actual trading software (you install)
- **My API Bridge** = Web interface that talks to MT5 (I built)
- **Your App** = Makes HTTP requests to my API (you use)

Just like a restaurant:
- Kitchen (MT5 Terminal) - you need to set it up
- Waiter (My API) - I built this to take orders
- Customer (Your App) - places orders via waiter



