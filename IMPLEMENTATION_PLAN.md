# Implementation Plan: Multi-User Account System

## Quick Start Implementation

This document provides step-by-step implementation for adding multi-user account support.

---

## Step 1: Create Supabase Table

Run this SQL in your Supabase SQL Editor:

```sql
-- Create mt5_accounts table
CREATE TABLE IF NOT EXISTS mt5_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    account_name VARCHAR(255) NOT NULL,
    login VARCHAR(50) NOT NULL,
    server VARCHAR(255) NOT NULL,
    encrypted_password TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    is_default BOOLEAN DEFAULT false,
    broker_name VARCHAR(100),
    account_type VARCHAR(20) DEFAULT 'demo',
    risk_limits JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id, login, server)
);

-- Indexes
CREATE INDEX idx_mt5_accounts_user_id ON mt5_accounts(user_id);
CREATE INDEX idx_mt5_accounts_active ON mt5_accounts(user_id, is_active) WHERE is_active = true;

-- Row Level Security
ALTER TABLE mt5_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own accounts" ON mt5_accounts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own accounts" ON mt5_accounts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own accounts" ON mt5_accounts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own accounts" ON mt5_accounts
    FOR DELETE USING (auth.uid() = user_id);
```

---

## Step 2: Add Account Management Endpoints

Add these endpoints to `mt5_api_bridge.py`:

### 2.1 Account Models

```python
class AccountConnectRequest(BaseModel):
    account_name: str
    login: int
    password: str
    server: str
    broker_name: Optional[str] = None
    account_type: str = "demo"  # "demo" or "live"
    set_as_default: bool = False
    risk_limits: Optional[Dict[str, Any]] = None

class AccountUpdateRequest(BaseModel):
    account_name: Optional[str] = None
    risk_limits: Optional[Dict[str, Any]] = None
    is_default: Optional[bool] = None
```

### 2.2 Account Manager Service

Create `services/account_manager.py`:

```python
from supabase import create_client
from cryptography.fernet import Fernet
import base64
import os
import logging

logger = logging.getLogger(__name__)

class AccountManager:
    def __init__(self, supabase_client):
        self.supabase = supabase_client
        # Use environment variable for encryption key
        key = os.getenv("ENCRYPTION_KEY", Fernet.generate_key().decode())
        self.cipher = Fernet(key.encode())
    
    def encrypt_password(self, password: str) -> str:
        """Encrypt password"""
        return self.cipher.encrypt(password.encode()).decode()
    
    def decrypt_password(self, encrypted: str) -> str:
        """Decrypt password"""
        return self.cipher.decrypt(encrypted.encode()).decode()
    
    async def create_account(self, user_id: str, account_data: dict) -> dict:
        """Create new MT5 account"""
        try:
            # Encrypt password
            encrypted_password = self.encrypt_password(account_data['password'])
            
            # Prepare account record
            account_record = {
                'user_id': user_id,
                'account_name': account_data['account_name'],
                'login': str(account_data['login']),
                'server': account_data['server'],
                'encrypted_password': encrypted_password,
                'broker_name': account_data.get('broker_name'),
                'account_type': account_data.get('account_type', 'demo'),
                'risk_limits': account_data.get('risk_limits', {}),
                'is_default': account_data.get('set_as_default', False)
            }
            
            # If setting as default, unset other defaults
            if account_record['is_default']:
                self.supabase.table('mt5_accounts').update({'is_default': False}).eq('user_id', user_id).execute()
            
            # Insert account
            result = self.supabase.table('mt5_accounts').insert(account_record).execute()
            
            if result.data:
                logger.info(f"✅ Account created: {result.data[0]['id']} for user {user_id}")
                return result.data[0]
            else:
                raise Exception("Failed to create account")
                
        except Exception as e:
            logger.error(f"Error creating account: {e}")
            raise
    
    async def get_account(self, user_id: str, account_id: str) -> dict:
        """Get account with decrypted password"""
        try:
            result = self.supabase.table('mt5_accounts').select('*').eq('id', account_id).eq('user_id', user_id).single().execute()
            
            if result.data:
                account = result.data.copy()
                # Decrypt password
                account['password'] = self.decrypt_password(account['encrypted_password'])
                return account
            else:
                return None
                
        except Exception as e:
            logger.error(f"Error getting account: {e}")
            return None
    
    async def list_accounts(self, user_id: str) -> list:
        """List all accounts for user"""
        try:
            result = self.supabase.table('mt5_accounts').select('id, account_name, login, server, broker_name, account_type, is_active, is_default, created_at').eq('user_id', user_id).eq('is_active', True).execute()
            return result.data if result.data else []
        except Exception as e:
            logger.error(f"Error listing accounts: {e}")
            return []
    
    async def get_default_account(self, user_id: str) -> dict:
        """Get user's default account"""
        try:
            result = self.supabase.table('mt5_accounts').select('*').eq('user_id', user_id).eq('is_default', True).eq('is_active', True).maybe_single().execute()
            
            if result.data:
                account = result.data.copy()
                account['password'] = self.decrypt_password(account['encrypted_password'])
                return account
            else:
                # Get first active account
                result = self.supabase.table('mt5_accounts').select('*').eq('user_id', user_id).eq('is_active', True).limit(1).execute()
                if result.data:
                    account = result.data[0].copy()
                    account['password'] = self.decrypt_password(account['encrypted_password'])
                    return account
            return None
        except Exception as e:
            logger.error(f"Error getting default account: {e}")
            return None
```

### 2.3 Account Switcher Service

Create `services/account_switcher.py`:

```python
from mt5linux import MetaTrader5
import logging

logger = logging.getLogger(__name__)

class AccountSwitcher:
    def __init__(self, rpc_host: str = "localhost", rpc_port: int = 8001):
        self.rpc_host = rpc_host
        self.rpc_port = rpc_port
        self.current_account = None  # {user_id: account_id}
        self.mt5_instances = {}  # {user_id: MT5 instance}
    
    def get_mt5_instance(self, user_id: str):
        """Get or create MT5 instance for user"""
        if user_id not in self.mt5_instances:
            self.mt5_instances[user_id] = MetaTrader5(host=self.rpc_host, port=self.rpc_port)
        return self.mt5_instances[user_id]
    
    async def switch_to_account(self, user_id: str, account: dict) -> bool:
        """Switch to user's account"""
        try:
            mt5 = self.get_mt5_instance(user_id)
            
            # Check if already logged in to this account
            current_info = mt5.account_info()
            if current_info and current_info.login == int(account['login']):
                logger.info(f"Already logged in to account {account['login']}")
                self.current_account[user_id] = account['id']
                return True
            
            # Initialize if needed
            if not mt5.initialize():
                logger.error("Failed to initialize MT5")
                return False
            
            # Login to account
            authorized = mt5.login(
                login=int(account['login']),
                password=account['password'],
                server=account['server']
            )
            
            if not authorized:
                error = mt5.last_error()
                logger.error(f"Login failed: {error}")
                return False
            
            # Verify login
            account_info = mt5.account_info()
            if account_info and account_info.login == int(account['login']):
                self.current_account[user_id] = account['id']
                logger.info(f"✅ Switched to account {account['login']} for user {user_id}")
                return True
            else:
                logger.error("Login verification failed")
                return False
                
        except Exception as e:
            logger.error(f"Error switching account: {e}")
            return False
    
    def ensure_account(self, user_id: str, account: dict) -> bool:
        """Ensure user is logged in to their account"""
        if self.current_account.get(user_id) == account['id']:
            # Already on this account
            mt5 = self.get_mt5_instance(user_id)
            account_info = mt5.account_info()
            if account_info and account_info.login == int(account['login']):
                return True
        
        # Need to switch
        return self.switch_to_account(user_id, account)
```

---

## Step 3: Update Main API

Add account management endpoints to `mt5_api_bridge.py`:

```python
from services.account_manager import AccountManager
from services.account_switcher import AccountSwitcher

# Initialize services
account_manager = AccountManager(supabase_client)
account_switcher = AccountSwitcher(
    rpc_host=os.getenv("MT5_RPC_HOST", "localhost"),
    rpc_port=int(os.getenv("MT5_RPC_PORT", "8001"))
)

# Helper to get user's current account
async def get_user_account(user_id: str):
    """Get user's current/default account"""
    account = await account_manager.get_default_account(user_id)
    if account:
        # Ensure we're logged in
        account_switcher.ensure_account(user_id, account)
    return account

# Account endpoints
@app.post("/api/v1/accounts/connect")
async def connect_account(
    request: AccountConnectRequest,
    user: dict = Depends(verify_token)
):
    """Connect/add a new MT5 account"""
    user_id = user['user_id']
    
    # First, verify credentials by logging in
    mt5 = get_mt5()
    authorized = mt5.login(
        login=request.login,
        password=request.password,
        server=request.server
    )
    
    if not authorized:
        error = mt5.last_error()
        raise HTTPException(status_code=400, detail=f"Login failed: {error}")
    
    # Get account info
    account_info = mt5.account_info()
    if not account_info:
        raise HTTPException(status_code=400, detail="Failed to get account info")
    
    # Store account in database
    account_data = {
        'account_name': request.account_name,
        'login': request.login,
        'password': request.password,
        'server': request.server,
        'broker_name': request.broker_name,
        'account_type': request.account_type,
        'set_as_default': request.set_as_default,
        'risk_limits': request.risk_limits or {}
    }
    
    account = await account_manager.create_account(user_id, account_data)
    
    return {
        "success": True,
        "account_id": account['id'],
        "account": {
            "login": account_info.login,
            "server": account_info.server,
            "balance": float(account_info.balance),
            "equity": float(account_info.equity)
        }
    }

@app.get("/api/v1/accounts")
async def list_accounts(user: dict = Depends(verify_token)):
    """List all accounts for user"""
    user_id = user['user_id']
    accounts = await account_manager.list_accounts(user_id)
    return {"accounts": accounts}

@app.post("/api/v1/accounts/{account_id}/switch")
async def switch_account(account_id: str, user: dict = Depends(verify_token)):
    """Switch to a specific account"""
    user_id = user['user_id']
    
    account = await account_manager.get_account(user_id, account_id)
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    
    success = await account_switcher.switch_to_account(user_id, account)
    if not success:
        raise HTTPException(status_code=400, detail="Failed to switch account")
    
    # Get current account info
    mt5 = account_switcher.get_mt5_instance(user_id)
    account_info = mt5.account_info()
    
    return {
        "success": True,
        "account": {
            "login": account_info.login,
            "server": account_info.server,
            "balance": float(account_info.balance)
        }
    }

# Update existing endpoints to use user's account
@app.get("/api/v1/account/info")
async def get_account_info(user: dict = Depends(verify_token)):
    """Get account information for current user"""
    user_id = user['user_id']
    
    # Get user's account
    account = await get_user_account(user_id)
    if not account:
        raise HTTPException(status_code=404, detail="No account connected. Please connect an account first.")
    
    # Get account info from MT5
    mt5 = account_switcher.get_mt5_instance(user_id)
    account_info = mt5.account_info()
    
    if not account_info:
        raise HTTPException(status_code=404, detail="Not connected to MT5")
    
    return {
        "login": account_info.login,
        "balance": float(account_info.balance),
        "equity": float(account_info.equity),
        # ... rest of account info
    }
```

---

## Step 4: Update All Trading Endpoints

All trading endpoints need to use the user's account:

```python
@app.post("/api/v1/trades")
async def place_order(
    request: TradeRequest,
    user: dict = Depends(verify_token)
):
    """Place a market order"""
    user_id = user['user_id']
    
    # Get user's account
    account = await get_user_account(user_id)
    if not account:
        raise HTTPException(status_code=404, detail="No account connected")
    
    # Get MT5 instance for this user
    mt5 = account_switcher.get_mt5_instance(user_id)
    
    # Execute trade...
    # (rest of the trading logic)
```

---

## Step 5: Environment Variables

Add to `.env`:

```bash
ENCRYPTION_KEY=your-fernet-encryption-key-here  # Generate with: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

---

## Step 6: Testing

1. **Test account connection:**
```bash
curl -X POST https://trade.trainflow.dev/api/v1/accounts/connect \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "account_name": "My Demo",
    "login": 5042856355,
    "password": "V!QzRxQ7",
    "server": "MetaQuotes-Demo"
  }'
```

2. **Test account switching:**
```bash
curl -X POST https://trade.trainflow.dev/api/v1/accounts/ACCOUNT_ID/switch \
  -H "Authorization: Bearer YOUR_TOKEN"
```

3. **Test trading with user's account:**
```bash
curl -X POST https://trade.trainflow.dev/api/v1/trades \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "EURUSD",
    "order_type": "buy",
    "volume": 0.1
  }'
```

---

## Next Steps

1. ✅ Create Supabase table
2. ✅ Implement account manager service
3. ✅ Implement account switcher service
4. ✅ Add account management endpoints
5. ✅ Update all trading endpoints
6. ✅ Test with multiple users
7. ✅ Deploy to production

---

This implementation allows:
- ✅ Multiple users with their own accounts
- ✅ Secure credential storage
- ✅ Account switching
- ✅ Trading on user's accounts
- ✅ Full account isolation

