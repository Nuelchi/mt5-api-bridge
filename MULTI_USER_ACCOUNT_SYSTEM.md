# Multi-User Account System for MT5 API Bridge

## Overview

Currently, the MT5 API Bridge connects to a single MT5 account. To support multiple users trading with their own accounts, we need to implement:

1. **Account Management**: Store and manage user MT5 account credentials
2. **Account Switching**: Login to different MT5 accounts per user
3. **Account Isolation**: Ensure users can only access their own accounts
4. **Trading Algorithms**: Execute trades on behalf of users' accounts

---

## Architecture

### Current (Single Account)
```
User → API → Single MT5 Account (Demo)
```

### Proposed (Multi-User)
```
User A → API → User A's MT5 Account
User B → API → User B's MT5 Account
User C → API → User C's MT5 Account
```

### Implementation Approach

**Option 1: Account Switching (Recommended)**
- Single MT5 Terminal instance
- Login/logout to switch between accounts
- Store credentials in Supabase (encrypted)
- Fast switching (1-2 seconds)

**Option 2: Multiple MT5 Terminals**
- One Docker container per user
- Better isolation but resource-intensive
- Not scalable for many users

**We'll use Option 1** - Account switching with credential storage.

---

## Database Schema

### Supabase Table: `mt5_accounts`

```sql
CREATE TABLE IF NOT EXISTS mt5_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    account_name VARCHAR(255) NOT NULL,
    login VARCHAR(50) NOT NULL,
    server VARCHAR(255) NOT NULL,
    encrypted_password TEXT NOT NULL,  -- Encrypted with Supabase vault
    is_active BOOLEAN DEFAULT true,
    is_default BOOLEAN DEFAULT false,
    broker_name VARCHAR(100),
    account_type VARCHAR(20),  -- 'demo' or 'live'
    risk_limits JSONB,  -- max_daily_loss, max_risk_per_trade, etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id, login, server)  -- One account per user per login/server
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

## API Endpoints

### 1. Connect/Add Account

**POST** `/api/v1/accounts/connect`

Connect a new MT5 account for the user.

**Request:**
```json
{
  "account_name": "My Demo Account",
  "login": "5042856355",
  "password": "V!QzRxQ7",
  "server": "MetaQuotes-Demo",
  "broker_name": "MetaQuotes",
  "account_type": "demo",
  "set_as_default": true
}
```

**Response:**
```json
{
  "success": true,
  "account_id": "uuid-here",
  "account": {
    "login": 5042856355,
    "server": "MetaQuotes-Demo",
    "balance": 100000.0,
    "equity": 100000.0
  }
}
```

**Implementation:**
1. Verify credentials by logging in to MT5
2. Encrypt password using Supabase Vault
3. Store account in database
4. Return account info

---

### 2. List User Accounts

**GET** `/api/v1/accounts`

Get all accounts for the authenticated user.

**Response:**
```json
{
  "accounts": [
    {
      "id": "uuid-1",
      "account_name": "My Demo Account",
      "login": 5042856355,
      "server": "MetaQuotes-Demo",
      "broker_name": "MetaQuotes",
      "account_type": "demo",
      "is_active": true,
      "is_default": true,
      "created_at": "2025-11-25T00:00:00Z"
    }
  ]
}
```

---

### 3. Switch Account

**POST** `/api/v1/accounts/{account_id}/switch`

Switch to a specific account for subsequent requests.

**Response:**
```json
{
  "success": true,
  "account": {
    "login": 5042856355,
    "server": "MetaQuotes-Demo",
    "balance": 100000.0
  }
}
```

**Implementation:**
1. Get account credentials from database
2. Logout from current MT5 account (if any)
3. Login to new account
4. Store current account in session/cache

---

### 4. Get Current Account

**GET** `/api/v1/accounts/current`

Get the currently active account for the user.

**Response:**
```json
{
  "account": {
    "id": "uuid-1",
    "login": 5042856355,
    "server": "MetaQuotes-Demo",
    "balance": 100000.0,
    "equity": 100000.0
  }
}
```

---

### 5. Update Account

**PUT** `/api/v1/accounts/{account_id}`

Update account settings (name, risk limits, etc.).

**Request:**
```json
{
  "account_name": "Updated Name",
  "risk_limits": {
    "max_daily_loss": 0.03,
    "max_risk_per_trade": 0.01
  }
}
```

---

### 6. Delete Account

**DELETE** `/api/v1/accounts/{account_id}`

Remove an account (soft delete - sets is_active = false).

---

## Account Context Management

### Session-Based Approach

Store current account per user session:

```python
# In-memory cache (Redis recommended for production)
user_accounts = {
    "user_id_1": "account_id_1",  # Current active account
    "user_id_2": "account_id_2",
}
```

### Request Flow

1. User makes API request with JWT token
2. Extract `user_id` from JWT
3. Check if user has active account in cache
4. If not, get default account from database
5. Switch to that account (if not already logged in)
6. Execute request on that account
7. Return response

---

## Trading Algorithms

### Algorithm Execution

When a trading algorithm needs to execute trades:

1. **Get User's Account**
   ```python
   account = get_user_account(user_id, account_id)
   ```

2. **Switch to Account**
   ```python
   switch_to_account(account)
   ```

3. **Execute Trades**
   ```python
   # All trading endpoints automatically use current account
   result = place_trade(symbol, order_type, volume)
   ```

4. **Log Trade**
   ```python
   # Store in trade_journal table
   log_trade(user_id, account_id, trade_result)
   ```

### Algorithm Endpoint

**POST** `/api/v1/algorithms/execute`

Execute a trading algorithm for a user's account.

**Request:**
```json
{
  "account_id": "uuid-here",
  "algorithm_id": "strategy-uuid",
  "parameters": {
    "symbol": "EURUSD",
    "risk_per_trade": 0.01,
    "max_positions": 3
  }
}
```

**Response:**
```json
{
  "success": true,
  "trades_executed": 2,
  "trades": [
    {
      "ticket": 12345678,
      "symbol": "EURUSD",
      "type": "buy",
      "volume": 0.1,
      "price": 1.15234
    }
  ]
}
```

---

## Security Considerations

### 1. Password Encryption

Use Supabase Vault for encryption:
```python
from supabase import create_client

# Encrypt password
encrypted = supabase.rpc('encrypt_password', {'password': password})

# Decrypt password (only for current user)
decrypted = supabase.rpc('decrypt_password', {'encrypted': encrypted})
```

### 2. Account Ownership Validation

Always verify user owns the account:
```python
def verify_account_ownership(user_id: str, account_id: str) -> bool:
    account = supabase.table('mt5_accounts').select('user_id').eq('id', account_id).single().execute()
    return account.data['user_id'] == user_id
```

### 3. Rate Limiting

Limit account switching to prevent abuse:
- Max 10 switches per hour per user
- Max 100 trades per hour per account

---

## Implementation Steps

### Phase 1: Account Management (Week 1)
- [ ] Create Supabase table schema
- [ ] Implement account CRUD endpoints
- [ ] Add password encryption/decryption
- [ ] Test account storage and retrieval

### Phase 2: Account Switching (Week 1-2)
- [ ] Implement MT5 login/logout
- [ ] Add account context management
- [ ] Update all endpoints to use current account
- [ ] Test account switching

### Phase 3: Trading Algorithms (Week 2)
- [ ] Add algorithm execution endpoint
- [ ] Implement trade logging
- [ ] Add risk management checks
- [ ] Test algorithm execution

### Phase 4: Production (Week 3)
- [ ] Add Redis for session management
- [ ] Implement rate limiting
- [ ] Add monitoring and logging
- [ ] Deploy to production

---

## Code Structure

```
mt5-api-bridge/
├── mt5_api_bridge.py          # Main API (updated)
├── services/
│   ├── account_manager.py      # Account CRUD operations
│   ├── account_switcher.py    # MT5 login/logout logic
│   ├── credential_encryption.py # Password encryption
│   └── algorithm_executor.py  # Algorithm execution
├── models/
│   └── account_models.py      # Pydantic models
└── database/
    └── supabase_client.py     # Supabase client wrapper
```

---

## Example Usage

### Frontend: Connect Account

```typescript
async function connectMT5Account(credentials: {
  account_name: string;
  login: string;
  password: string;
  server: string;
}) {
  const response = await fetch('https://trade.trainflow.dev/api/v1/accounts/connect', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(credentials)
  });
  
  return await response.json();
}
```

### Frontend: Execute Algorithm

```typescript
async function executeAlgorithm(accountId: string, algorithmId: string, params: any) {
  const response = await fetch('https://trade.trainflow.dev/api/v1/algorithms/execute', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      account_id: accountId,
      algorithm_id: algorithmId,
      parameters: params
    })
  });
  
  return await response.json();
}
```

---

## Migration from Single Account

1. **Backup current setup**
2. **Create database table**
3. **Migrate current account** to first user's account
4. **Deploy new endpoints**
5. **Update frontend** to use new endpoints
6. **Test thoroughly**

---

## Next Steps

1. Review this document
2. Create Supabase table
3. Implement account management endpoints
4. Test with multiple users
5. Deploy to production

---

**Questions?** This system allows:
- ✅ Multiple users with their own accounts
- ✅ Secure credential storage
- ✅ Account switching
- ✅ Trading algorithm execution
- ✅ Full account isolation

