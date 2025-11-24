# MT5 API Bridge - Standalone Implementation

Standalone MT5 API Bridge server for Linux VPS deployment. Provides web API access to MT5 functionality with Supabase JWT authentication.

## 🏗️ Architecture

```
Frontend (Next.js)
  ↓ JWT Token
MT5 API Bridge (FastAPI)
  ↓ Supabase Auth
MT5 Terminal (Linux VPS)
```

## 📦 Files

- `mt5_api_bridge.py` - Main FastAPI server
- `test_jwt_auth.py` - JWT authentication test
- `deploy_vps.sh` - Automated deployment script
- `requirements.txt` - Python dependencies
- `.env.example` - Environment variables template

## 🚀 Quick Start

### 1. Local Testing

```bash
# Install dependencies
pip install -r requirements.txt

# Create .env file
cp .env.example .env
# Edit .env with your Supabase credentials

# Test JWT authentication
python test_jwt_auth.py

# Start server
python mt5_api_bridge.py
```

### 2. VPS Deployment

```bash
# Upload files to VPS
scp -r mt5-api-bridge/* root@your-vps-ip:/opt/mt5-api-bridge/

# SSH into VPS
ssh root@your-vps-ip

# Run deployment script
cd /opt/mt5-api-bridge
chmod +x deploy_vps.sh
sudo ./deploy_vps.sh
```

## 🔐 Authentication

Uses Supabase JWT authentication (same as Trainflow backend):
- Verifies tokens using `supabase_client.auth.get_user(token)`
- Returns user info in same format as backend
- Compatible with frontend JWT tokens

## 📡 API Endpoints

- `GET /health` - Health check
- `GET /api/v1/account/info` - Account information
- `GET /api/v1/market-data/{symbol}` - Historical data
- `POST /api/v1/trades` - Place order
- `GET /api/v1/positions` - Get positions
- `DELETE /api/v1/positions/{ticket}` - Close position

See `/docs` for full API documentation.

## 🌐 Subdomain

Configured for: `trade.trainflow.dev`

## 📝 Environment Variables

See `.env.example` for required variables:
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_ANON_KEY` - Your Supabase anon key
- `PORT` - Server port (default: 8001)
- `CORS_ORIGINS` - Allowed origins
- `DOMAIN` - Your domain for SSL

## 🧪 Testing

```bash
# Test JWT authentication
python test_jwt_auth.py

# Test API endpoint
curl http://localhost:8001/health
```

## 📚 Documentation

- Full API docs: `http://localhost:8001/docs`
- ReDoc: `http://localhost:8001/redoc`

