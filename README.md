# MT5 API Bridge - Production Documentation

A production-ready MetaTrader 5 API bridge for Linux VPS deployment. Provides secure web API access to MT5 trading functionality with Supabase JWT authentication.

**Live API:** https://trade.trainflow.dev  
**API Documentation:** https://trade.trainflow.dev/docs  
**Test Status:** ✅ 10/10 Tests Passing - Fully Operational

---

## 🚀 Ready to Use!

Your MT5 API Bridge is **fully deployed and tested**. You can start using it right now:

1. **Get a Supabase JWT token** (same as your backend)
2. **Make API calls** to `https://trade.trainflow.dev`
3. **Trade, fetch market data, manage positions** - all working!

```bash
# Quick Test
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://trade.trainflow.dev/api/v1/account/info
```

**What's Working:**
- ✅ JWT Authentication
- ✅ Market Data (real-time & historical)
- ✅ Place Trades (buy/sell)
- ✅ Close Positions
- ✅ Account Information
- ✅ All major currency pairs

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [API Endpoints](#api-endpoints)
- [Authentication](#authentication)
- [Code Examples](#code-examples)
- [Error Handling](#error-handling)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

The MT5 API Bridge provides a RESTful API interface to MetaTrader 5, allowing your frontend applications to:
- Fetch real-time and historical market data
- Get account information and balance
- Place and manage trades
- View open positions
- Access available trading symbols

**Key Features:**
- ✅ Supabase JWT authentication (same as your backend)
- ✅ Docker-based MT5 Terminal (stable and reliable)
- ✅ SSL/HTTPS enabled with auto-renewal
- ✅ Production-ready with Nginx reverse proxy
- ✅ **Fully tested trading functionality** (10/10 tests passing)
- ✅ Smart filling mode detection (works with any broker)
- ✅ Comprehensive error handling
- ✅ Full API documentation (Swagger/OpenAPI)
- 🔜 Multi-user account system (ready to implement)

---

## 🏗️ Architecture

```
┌─────────────────┐
│   Frontend      │
│  (Next.js App)  │
└────────┬────────┘
         │ HTTPS + JWT Token
         ▼
┌─────────────────────────────────┐
│   Nginx (Reverse Proxy)          │
│   https://trade.trainflow.dev    │
└────────┬─────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│   FastAPI Server                │
│   Port: 8000                    │
│   - JWT Verification            │
│   - Request Routing             │
└────────┬─────────────────────────┘
         │ RPyC (Remote Python Call)
         ▼
┌─────────────────────────────────┐
│   Docker Container               │
│   - MT5 Terminal (Wine)          │
│   - Windows Python               │
│   - RPyC Server (Port 8001)      │
└─────────────────────────────────┘
```

### Components

1. **Frontend**: Your Next.js application sends requests with JWT tokens
2. **Nginx**: Reverse proxy handling SSL and routing to FastAPI
3. **FastAPI Server**: Validates JWT tokens and processes API requests
4. **Docker Container**: Runs MT5 Terminal in Wine with RPyC bridge
5. **MT5 Terminal**: The actual MetaTrader 5 terminal connected to broker

---

## 🚀 Quick Start

### For Frontend Developers

The API is already deployed and running at: **https://trade.trainflow.dev**

**All you need:**
1. Get a JWT token from your Supabase auth (same as your backend)
2. Include it in the `Authorization` header
3. Make requests to the API endpoints

**Example:**
```javascript
const token = await getSupabaseToken(); // Your existing auth

const response = await fetch('https://trade.trainflow.dev/api/v1/account/info', {
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  }
});

const account = await response.json();
console.log(account.balance); // 100000.0
```

---

## 📡 API Endpoints

### Base URL
```
Production: https://trade.trainflow.dev
Local:      http://localhost:8000
```

### Authentication
All endpoints (except `/health`) require JWT authentication:
```
Authorization: Bearer <your-jwt-token>
```

---

### 1. Health Check

**GET** `/health`

No authentication required. Returns API and MT5 connection status.

**Response:**
```json
{
  "status": "healthy",
  "mt5_available": true,
  "mt5_connected": true,
  "mt5_library": "mt5linux",
  "supabase_available": true,
  "account": 5042856355,
  "timestamp": "2025-11-25T02:25:21.821618"
}
```

**Status Values:**
- `healthy`: MT5 is connected and working
- `degraded`: MT5 library available but not connected
- `unhealthy`: Critical error

---

### 2. Account Information

**GET** `/api/v1/account/info`

Get current account information (balance, equity, margin, etc.).

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
```json
{
  "login": 5042856355,
  "balance": 100000.0,
  "equity": 100000.0,
  "margin": 0.0,
  "free_margin": 100000.0,
  "margin_level": 0.0,
  "profit": 0.0,
  "server": "MetaQuotes-Demo",
  "currency": "USD",
  "leverage": 100,
  "company": "MetaQuotes Ltd."
}
```

**JavaScript Example:**
```javascript
async function getAccountInfo(token) {
  const response = await fetch('https://trade.trainflow.dev/api/v1/account/info', {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  
  if (!response.ok) {
    throw new Error(`API error: ${response.status}`);
  }
  
  return await response.json();
}
```

---

### 3. Market Data - Historical Bars

**GET** `/api/v1/market-data/{symbol}`

Get historical OHLCV data for a symbol.

**Parameters:**
- `symbol` (path): Trading symbol (e.g., `EURUSD`, `GBPUSD`)
- `timeframe` (query): `M1`, `M5`, `M15`, `M30`, `H1`, `H4`, `D1`, `W1`, `MN1` (default: `H1`)
- `bars` (query): Number of bars to retrieve (1-10000, default: 100)

**Example:**
```
GET /api/v1/market-data/EURUSD?timeframe=H1&bars=100
```

**Response:**
```json
{
  "symbol": "EURUSD",
  "timeframe": "H1",
  "count": 100,
  "data": [
    {
      "time": 1764010800,
      "open": 1.15181,
      "high": 1.15199,
      "low": 1.15113,
      "close": 1.15176,
      "volume": 1848
    },
    // ... more bars
  ]
}
```

**JavaScript Example:**
```javascript
async function getMarketData(symbol, timeframe = 'H1', bars = 100) {
  const url = `https://trade.trainflow.dev/api/v1/market-data/${symbol}?timeframe=${timeframe}&bars=${bars}`;
  
  const response = await fetch(url, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  
  const data = await response.json();
  
  // Convert timestamps to Date objects
  data.data = data.data.map(bar => ({
    ...bar,
    time: new Date(bar.time * 1000)
  }));
  
  return data;
}

// Usage
const eurusdData = await getMarketData('EURUSD', 'H1', 100);
console.log(`Got ${eurusdData.count} bars of EURUSD H1 data`);
```

---

### 4. Market Data - Date Range

**GET** `/api/v1/market-data/{symbol}/range`

Get historical data for a specific date range.

**Parameters:**
- `symbol` (path): Trading symbol
- `timeframe` (query): Timeframe (default: `H1`)
- `start_date` (query, optional): ISO 8601 date string (e.g., `2025-11-01T00:00:00Z`)
- `end_date` (query, optional): ISO 8601 date string (default: now)

**Example:**
```
GET /api/v1/market-data/EURUSD/range?timeframe=H1&start_date=2025-11-01T00:00:00Z&end_date=2025-11-25T00:00:00Z
```

**JavaScript Example:**
```javascript
async function getMarketDataRange(symbol, timeframe, startDate, endDate) {
  const params = new URLSearchParams({
    timeframe,
    start_date: startDate.toISOString(),
    end_date: endDate.toISOString()
  });
  
  const url = `https://trade.trainflow.dev/api/v1/market-data/${symbol}/range?${params}`;
  
  const response = await fetch(url, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  
  return await response.json();
}
```

---

### 5. Place Trade

**POST** `/api/v1/trades`

Place a market order (buy or sell).

**Request Body:**
```json
{
  "symbol": "EURUSD",
  "order_type": "buy",  // or "sell"
  "volume": 0.1,
  "price": null,        // optional, uses market price if null
  "stop_loss": 1.1500, // optional
  "take_profit": 1.1600 // optional
}
```

**Response:**
```json
{
  "success": true,
  "ticket": 12345678,
  "price": 1.15234,
  "volume": 0.1,
  "symbol": "EURUSD",
  "type": "buy"
}
```

**JavaScript Example:**
```javascript
async function placeTrade(symbol, orderType, volume, stopLoss = null, takeProfit = null) {
  const response = await fetch('https://trade.trainflow.dev/api/v1/trades', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      symbol,
      order_type: orderType, // 'buy' or 'sell'
      volume,
      stop_loss: stopLoss,
      take_profit: takeProfit
    })
  });
  
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.detail || 'Trade failed');
  }
  
  return await response.json();
}

// Usage
const trade = await placeTrade('EURUSD', 'buy', 0.1, 1.1500, 1.1600);
console.log(`Trade placed: Ticket ${trade.ticket} at ${trade.price}`);
```

---

### 6. Get Open Positions

**GET** `/api/v1/positions`

Get all open trading positions.

**Response:**
```json
{
  "positions": [
    {
      "ticket": 12345678,
      "symbol": "EURUSD",
      "type": "buy",
      "volume": 0.1,
      "price_open": 1.15234,
      "price_current": 1.15250,
      "profit": 1.6,
      "swap": 0.0,
      "time_open": 1764043200,
      "comment": "API Trade"
    }
  ]
}
```

**JavaScript Example:**
```javascript
async function getPositions() {
  const response = await fetch('https://trade.trainflow.dev/api/v1/positions', {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  
  const data = await response.json();
  return data.positions;
}
```

---

### 7. Close Position

**DELETE** `/api/v1/positions/{ticket}`

Close a specific position by ticket number.

**Example:**
```
DELETE /api/v1/positions/12345678
```

**Response:**
```json
{
  "success": true,
  "ticket": 12345678,
  "volume": 0.1,
  "price": 1.15250
}
```

**JavaScript Example:**
```javascript
async function closePosition(ticket) {
  const response = await fetch(`https://trade.trainflow.dev/api/v1/positions/${ticket}`, {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  
  return await response.json();
}
```

---

### 8. Get Available Symbols

**GET** `/api/v1/symbols`

Get list of all available trading symbols.

**Response:**
```json
{
  "symbols": [
    "EURUSD",
    "GBPUSD",
    "USDJPY",
    "USDCHF",
    "AUDUSD",
    "USDCAD",
    "NZDUSD",
    // ... more symbols
  ]
}
```

---

## 🔐 Authentication

### How It Works

The API uses **Supabase JWT authentication**, identical to your existing backend:

1. User logs in via Supabase Auth (in your frontend)
2. Supabase returns a JWT token
3. Frontend includes token in `Authorization` header
4. API verifies token by:
   - Decoding JWT payload (checks `iss` for Supabase)
   - Extracting user info from payload
   - Verifying token hasn't expired
   - Fallback to `supabase.auth.get_user()` if needed

### Token Format

The JWT token contains:
- `sub`: User ID (UUID)
- `email`: User email
- `exp`: Expiration timestamp
- `iss`: Issuer (Supabase URL)

### Implementation

**Frontend (React/Next.js):**
```typescript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Get current session token
const { data: { session } } = await supabase.auth.getSession();
const token = session?.access_token;

// Use in API calls
const response = await fetch('https://trade.trainflow.dev/api/v1/account/info', {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});
```

**Error Handling:**
```typescript
if (response.status === 401) {
  // Token expired or invalid
  // Redirect to login or refresh token
  await supabase.auth.refreshSession();
}
```

---

## 💻 Code Examples

### Complete React Hook Example

```typescript
import { useState, useEffect } from 'react';
import { useSupabaseClient } from '@supabase/auth-helpers-react';

const API_BASE = 'https://trade.trainflow.dev';

export function useMT5API() {
  const supabase = useSupabaseClient();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const getToken = async () => {
    const { data: { session } } = await supabase.auth.getSession();
    return session?.access_token;
  };

  const apiCall = async (endpoint: string, options: RequestInit = {}) => {
    setLoading(true);
    setError(null);

    try {
      const token = await getToken();
      if (!token) {
        throw new Error('Not authenticated');
      }

      const response = await fetch(`${API_BASE}${endpoint}`, {
        ...options,
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
          ...options.headers,
        },
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.detail || `API error: ${response.status}`);
      }

      return await response.json();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
      throw err;
    } finally {
      setLoading(false);
    }
  };

  return {
    loading,
    error,
    // Account methods
    getAccountInfo: () => apiCall('/api/v1/account/info'),
    
    // Market data methods
    getMarketData: (symbol: string, timeframe: string = 'H1', bars: number = 100) =>
      apiCall(`/api/v1/market-data/${symbol}?timeframe=${timeframe}&bars=${bars}`),
    
    getMarketDataRange: (symbol: string, timeframe: string, startDate: Date, endDate: Date) => {
      const params = new URLSearchParams({
        timeframe,
        start_date: startDate.toISOString(),
        end_date: endDate.toISOString(),
      });
      return apiCall(`/api/v1/market-data/${symbol}/range?${params}`);
    },
    
    // Trading methods
    placeTrade: (symbol: string, orderType: 'buy' | 'sell', volume: number, stopLoss?: number, takeProfit?: number) =>
      apiCall('/api/v1/trades', {
        method: 'POST',
        body: JSON.stringify({
          symbol,
          order_type: orderType,
          volume,
          stop_loss: stopLoss,
          take_profit: takeProfit,
        }),
      }),
    
    getPositions: () => apiCall('/api/v1/positions'),
    
    closePosition: (ticket: number) =>
      apiCall(`/api/v1/positions/${ticket}`, { method: 'DELETE' }),
    
    getSymbols: () => apiCall('/api/v1/symbols'),
  };
}

// Usage in component
function TradingDashboard() {
  const mt5 = useMT5API();
  const [account, setAccount] = useState(null);
  const [marketData, setMarketData] = useState(null);

  useEffect(() => {
    // Load account info
    mt5.getAccountInfo().then(setAccount).catch(console.error);
    
    // Load market data
    mt5.getMarketData('EURUSD', 'H1', 100).then(setMarketData).catch(console.error);
  }, []);

  const handleTrade = async () => {
    try {
      const result = await mt5.placeTrade('EURUSD', 'buy', 0.1, 1.1500, 1.1600);
      console.log('Trade placed:', result);
    } catch (err) {
      console.error('Trade failed:', err);
    }
  };

  if (mt5.loading) return <div>Loading...</div>;
  if (mt5.error) return <div>Error: {mt5.error}</div>;

  return (
    <div>
      <h2>Account: ${account?.balance}</h2>
      <button onClick={handleTrade}>Place Trade</button>
    </div>
  );
}
```

---

## ⚠️ Error Handling

### HTTP Status Codes

- `200 OK`: Request successful
- `400 Bad Request`: Invalid parameters or trade failed
- `401 Unauthorized`: Invalid or expired JWT token
- `404 Not Found`: Symbol not found or no data available
- `500 Internal Server Error`: Server error
- `503 Service Unavailable`: MT5 not connected

### Error Response Format

```json
{
  "detail": "Error message description"
}
```

### Common Errors

**1. Token Expired (401)**
```json
{
  "detail": "Token has expired"
}
```
**Solution:** Refresh the session or redirect to login

**2. MT5 Not Connected (503)**
```json
{
  "detail": "MT5 not connected. Ensure MT5 Terminal is running with RPC server active."
}
```
**Solution:** Check MT5 Terminal status (usually auto-resolves)

**3. Symbol Not Found (404)**
```json
{
  "detail": "Symbol EURUSD not found"
}
```
**Solution:** Check symbol name or use `/api/v1/symbols` to get available symbols

**4. No Market Data (404)**
```json
{
  "detail": "No data for EURUSD"
}
```
**Solution:** Symbol may not be available on this broker, or timeframe is invalid

### Error Handling Example

```typescript
async function safeApiCall<T>(apiCall: () => Promise<T>): Promise<T | null> {
  try {
    return await apiCall();
  } catch (error) {
    if (error instanceof Response) {
      const errorData = await error.json();
      
      switch (error.status) {
        case 401:
          // Token expired - refresh or redirect
          console.error('Authentication failed:', errorData.detail);
          // Handle re-authentication
          break;
        case 404:
          // Resource not found
          console.error('Not found:', errorData.detail);
          break;
        case 503:
          // Service unavailable
          console.error('MT5 not available:', errorData.detail);
          // Show user-friendly message
          break;
        default:
          console.error('API error:', errorData.detail);
      }
    } else {
      console.error('Network error:', error);
    }
    return null;
  }
}
```

---

## 🚀 Deployment

### Production Setup

The API is already deployed and running on:
- **URL:** https://trade.trainflow.dev
- **Status:** Production-ready
- **SSL:** Enabled (Let's Encrypt)
- **MT5:** Running in Docker container

### Architecture Details

- **FastAPI Server:** Port 8000 (internal)
- **Nginx:** Reverse proxy on ports 80/443
- **Docker MT5:** Port 8001 (RPyC server, internal)
- **VNC Access:** Port 3000 (for MT5 GUI access)

### For DevOps/Backend Engineers

See deployment documentation:
- `DOCKER_SETUP_GUIDE.md` - Docker MT5 setup
- `DEPLOYMENT_STEPS.md` - Deployment instructions
- `VPS_SETUP_TODO.md` - VPS setup checklist

---

## 🔧 Troubleshooting

### API Returns 401 Unauthorized

**Problem:** JWT token is invalid or expired

**Solutions:**
1. Check token expiration: Decode JWT and check `exp` claim
2. Refresh session: `await supabase.auth.refreshSession()`
3. Re-authenticate: Redirect user to login

### API Returns 503 Service Unavailable

**Problem:** MT5 Terminal is not connected

**Solutions:**
1. Check health endpoint: `GET /health`
2. If `mt5_connected: false`, MT5 Terminal needs to be logged in
3. Access VNC: http://147.182.206.223:3000
4. Log in to MT5 Terminal manually
5. Wait 30 seconds and retry

### Market Data Returns 404

**Problem:** Symbol not found or no data available

**Solutions:**
1. Check available symbols: `GET /api/v1/symbols`
2. Verify symbol name (case-sensitive, e.g., `EURUSD` not `eurusd`)
3. Check if symbol is available on your broker
4. Try different timeframe

### Slow Response Times

**Problem:** API responses are slow

**Solutions:**
1. Large data requests: Reduce `bars` parameter
2. Symbols endpoint: Can be slow with many symbols (normal)
3. Network: Check your connection speed
4. Server load: Check VPS resources

---

## ✅ Testing & Verification

### Latest Test Results (Nov 25, 2025)

All API endpoints have been tested and verified working:

```bash
🧪 MT5 Login and Trading Test Suite
======================================================================
API URL: https://trade.trainflow.dev
MT5 Account: 5042856355 (Demo)
Server: MetaQuotes-Demo

Test Results: 10/10 PASSED ✅

✅ PASS - Health Check
✅ PASS - Connect/Login Account  
✅ PASS - Get Account Info
✅ PASS - Get Positions
✅ PASS - Get Market Data
✅ PASS - Place Buy Order (Ticket: 54123724512 @ 1.15274)
✅ PASS - Place Sell Order (Ticket: 54123724563 @ 1.15273)
✅ PASS - Get Positions (After)
✅ PASS - Close Position (Successfully closed at 1.15271)
✅ PASS - Account Info (After)

🎉 All tests passed! API is fully functional!
```

**Key Achievements:**
- ✅ JWT authentication working perfectly
- ✅ Real-time market data retrieval
- ✅ Successful order placement (buy/sell)
- ✅ Position management and closing
- ✅ Smart filling mode detection (auto-detects broker requirements)
- ✅ Account balance tracking in real-time

### Running Tests

To verify the API yourself:

```bash
# On VPS
cd /opt/mt5-api-bridge
python3 test_login_and_trading.py
```

---

## 🔮 Multi-User Account System

The bridge now supports **multiple MT5 accounts per Supabase user** plus account-specific switching for algorithmic execution. Trainflow’s backend still owns encryption (credentials are encrypted via the existing `encrypt_password`/`decrypt_password` RPCs), and the bridge consumes the decrypted data only at login time.

### Account Endpoints (FastAPI)

| Method | Path | Description |
| --- | --- | --- |
| `POST` | `/api/v1/accounts/connect` | Verify MT5 credentials, store them in Supabase, set default account |
| `GET` | `/api/v1/accounts` | List the caller’s MT5 accounts |
| `GET` | `/api/v1/accounts/current` | Return the active MT5 account (auto-switches if needed) |
| `POST` | `/api/v1/accounts/{account_id}/switch` | Programmatically log into a specific account |
| `PUT` | `/api/v1/accounts/{account_id}` | Update metadata or risk limits |
| `DELETE` | `/api/v1/accounts/{account_id}` | Soft-delete (deactivate) an account |

Every trading/market-data endpoint now enforces “active account context” — the bridge automatically switches the MT5 terminal to the right login before executing a request. Because MT5 allows only one session at a time, sessions are serialized with a global lock; account switching takes ~1–2 seconds.

### Database Integration

- Uses the existing `mt5_accounts` table in Supabase (requires extra columns `account_name`, `broker_name`, `account_type`, `encrypted_password`, `risk_limits`, `is_default`, `is_active`)
- Enforce a unique constraint on `(user_id, login, server)` so upserts can target the correct row:
  ```sql
  ALTER TABLE public.mt5_accounts
      ADD CONSTRAINT mt5_accounts_user_login_server_key
      UNIQUE (user_id, login, server);
  ```
- Passwords are encrypted/decrypted via the backend’s Fernet-based RPC helpers (`encrypt_password` / `decrypt_password`)
- Set `SUPABASE_SERVICE_KEY` (service-role key) on the bridge so writes bypass RLS
- Each record is scoped to a Supabase user (RLS should still enforce `auth.uid() = user_id` for non-service traffic)

Schema reference:
```sql
-- mt5_accounts table (already exists in your backend)
CREATE TABLE mt5_accounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  broker_name TEXT NOT NULL,
  account_number INTEGER NOT NULL,
  account_password_encrypted TEXT NOT NULL,
  server TEXT NOT NULL,
  account_type TEXT CHECK (account_type IN ('demo', 'live')),
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Algorithm Execution

Algorithms (or the backend scheduler) call `POST /api/v1/accounts/{account_id}/switch` before placing trades. Once switched, the standard trading endpoints (`/api/v1/trades`, `/api/v1/positions`, etc.) operate against that user’s account until another switch occurs. The bridge exposes hooks for future features (e.g., `/api/v1/algorithms/execute`) in `MULTI_USER_ACCOUNT_SYSTEM.md`.

🎯 Result: every Trainflow user can connect multiple demo/live accounts, and Trainflow can trade on their behalf without manual MT5 intervention.

### 🔧 Backend Encryption Service (Configure This!)

The bridge now uses the Trainflow backend to perform all credential encryption/decryption.  
Configure the following environment variables on the VPS before starting the bridge:

```
TRAINFLOW_BACKEND_URL=https://trainflow-backend-1.onrender.com
TRAINFLOW_SERVICE_KEY=<same value as backend MT5_ENCRYPTION_SERVICE_KEY>
```

On the backend, add the matching key to `.env`:

```
MT5_ENCRYPTION_SERVICE_KEY=<shared-secret>
```

With the shared service key in place the bridge securely calls
`/api/v1/accounts/encrypt` and `/api/v1/accounts/decrypt` to protect MT5
passwords before writing them to Supabase. No Supabase RPC setup is
required anymore—all multi-user endpoints work out of the box once the
service key is configured.

---

## 📚 Additional Resources

### API Documentation

- **Swagger UI:** https://trade.trainflow.dev/docs
- **ReDoc:** https://trade.trainflow.dev/redoc

### Testing

Test scripts are available in the repository:
- `test_api_with_auth.py` - Comprehensive API tests
- `test_jwt_local.py` - JWT verification tests

### Support

For issues or questions:
1. Check API health: `GET /health`
2. Review API logs: `journalctl -u mt5-api -f`
3. Check Docker logs: `docker logs mt5 -f`

---

## 🔒 Security Notes

- All endpoints (except `/health`) require authentication
- JWT tokens are verified on every request
- Tokens expire after 1 hour (Supabase default)
- HTTPS is enforced (HTTP redirects to HTTPS)
- CORS is configured for your frontend domains

---

## 📝 Changelog

### Version 1.1.0 (Current - Nov 25, 2025)
- ✅ **Trading fully operational** - All tests passing (10/10)
- ✅ **Smart filling mode detection** - Auto-detects and tries multiple filling modes
- ✅ Successful buy/sell order placement
- ✅ Position closing working perfectly
- ✅ Real-time account balance tracking
- ✅ Improved JWT token verification (matches backend)
- ✅ Enhanced error handling for trading operations

### Version 1.0.0 (Nov 24, 2025)
- ✅ Initial production release
- ✅ Docker-based MT5 setup (gmag11/metatrader5_vnc)
- ✅ Supabase JWT authentication
- ✅ Full API endpoint coverage
- ✅ SSL/HTTPS enabled with Let's Encrypt
- ✅ Production deployment on trade.trainflow.dev
- ✅ Nginx reverse proxy configuration
- ✅ Systemd service management

---

## 🤝 Integration with Your Backend

This API bridge is designed to work alongside your existing backend:

- **Same Authentication:** Uses Supabase JWT (same tokens)
- **Same User Base:** Same Supabase project
- **Complementary:** Handles MT5-specific operations
- **Independent:** Can be used separately or integrated

**Example Integration:**
```typescript
// In your backend or frontend
const mt5Response = await fetch('https://trade.trainflow.dev/api/v1/account/info', {
  headers: {
    'Authorization': `Bearer ${userToken}` // Same token as your backend
  }
});
```

---

**Last Updated:** November 25, 2025  
**API Version:** 1.1.0  
**Status:** ✅ Production Ready - All Tests Passing (10/10)
