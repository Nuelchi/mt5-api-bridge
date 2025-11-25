#!/usr/bin/env python3
"""
MT5 API Bridge - Standalone FastAPI Server
Web API for MT5 trading and data access on Linux VPS
Uses Supabase JWT authentication (same as Trainflow backend)
"""

from fastapi import FastAPI, Depends, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta
import logging
import os
import jwt
import time

# Supabase authentication (same as backend)
from supabase import create_client, Client

# Try to import MT5 library
MT5_INSTANCE = None
MT5_AVAILABLE = False
MT5_LIBRARY = None
MetaTrader5 = None
mt5_module = None

try:
    from mt5linux import MetaTrader5
    MT5_LIBRARY = "mt5linux"
    MT5_AVAILABLE = True
except ImportError:
    try:
        import MetaTrader5 as mt5_module
        MT5_LIBRARY = "MetaTrader5"
        MT5_AVAILABLE = True
    except ImportError:
        MT5_AVAILABLE = False
        MT5_LIBRARY = None

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Load environment variables
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "")

# Initialize Supabase client (same as backend)
try:
    supabase_client: Client = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
    SUPABASE_AVAILABLE = True
    logger.info("✅ Supabase client initialized successfully")
except Exception as e:
    logger.warning(f"⚠️  Supabase client initialization failed: {e}")
    supabase_client = None
    SUPABASE_AVAILABLE = False

app = FastAPI(
    title="MT5 API Bridge",
    description="Web API for MT5 trading and data access",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS - configure with your frontend domain
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

security = HTTPBearer()

# Supabase JWT verification (same as backend security.py)
async def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> Dict[str, Any]:
    """
    Verify JWT token using Supabase (same as backend core/security.py)
    Matches the exact implementation from trainflow-backend-c
    """
    import jwt
    import time
    
    token = credentials.credentials
    
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    try:
        # First, try to decode the JWT without verification to check if it's a Supabase token
        # Supabase tokens have 'iss' field pointing to Supabase auth endpoint
        try:
            unverified_payload = jwt.decode(token, options={"verify_signature": False})
            
            # Check if this is a Supabase token
            iss = unverified_payload.get('iss', '')
            if 'supabase.co' in iss or 'supabase' in iss.lower():
                # This is a Supabase JWT - extract user info from payload
                user_id = unverified_payload.get('sub')
                email = unverified_payload.get('email')
                
                if not user_id:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Invalid Supabase token: missing user identifier",
                        headers={"WWW-Authenticate": "Bearer"},
                    )
                
                # Verify token hasn't expired
                exp = unverified_payload.get('exp')
                if exp and exp < time.time():
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Token has expired",
                        headers={"WWW-Authenticate": "Bearer"},
                    )
                
                logger.debug(f"Authenticated Supabase user: {user_id}")
                return {
                    "user_id": user_id,
                    "email": email,
                    "provider": "supabase",
                    "payload": unverified_payload
                }
        except jwt.DecodeError:
            pass  # Not a valid JWT structure, try other methods
        except HTTPException:
            raise
        
        # Try Supabase auth.get_user (for session tokens) as fallback
        if SUPABASE_AVAILABLE and supabase_client:
            try:
                response = supabase_client.auth.get_user(token)
                if response.user:
                    return {
                        "user_id": response.user.id,
                        "email": response.user.email,
                        "provider": "supabase"
                    }
            except Exception as e:
                logger.debug(f"Supabase auth.get_user failed: {e}")
        
        # If we get here, token verification failed
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    except HTTPException:
        raise
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        logger.error(f"Token verification error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token verification failed",
            headers={"WWW-Authenticate": "Bearer"},
        )

# ============ MODELS ============

class ConnectRequest(BaseModel):
    login: int
    password: str
    server: str

class TradeRequest(BaseModel):
    symbol: str
    order_type: str  # "buy" or "sell"
    volume: float
    price: Optional[float] = None
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None

# ============ INITIALIZATION ============

@app.on_event("startup")
async def startup():
    """Initialize MT5 on startup"""
    global MT5_INSTANCE
    
    logger.info("🚀 Starting MT5 API Bridge")
    logger.info(f"📚 MT5 Library: {MT5_LIBRARY}")
    logger.info(f"🔐 Supabase: {'✅ Available' if SUPABASE_AVAILABLE else '❌ Not Available'}")
    
    if not MT5_AVAILABLE:
        logger.warning("⚠️  MT5 library not available - running in simulation mode")
        return
    
    # Initialize MT5 connection based on library type
    try:
        if MT5_LIBRARY == "mt5linux":
            # mt5linux uses RPC - connect to running MT5 terminal
            logger.info("🔌 Connecting to MT5 Terminal via RPC...")
            logger.info("   Note: MT5 Terminal must be running with RPC server active")
            
            # Get RPC connection settings from environment
            rpc_host = os.getenv("MT5_RPC_HOST", "localhost")
            rpc_port = int(os.getenv("MT5_RPC_PORT", "8001"))  # Docker uses 8001
            
            try:
                MT5_INSTANCE = MetaTrader5(host=rpc_host, port=rpc_port)
                logger.info(f"✅ Created MT5 instance for {rpc_host}:{rpc_port}")
                
                # Initialize MT5 connection
                logger.info("   Initializing MT5 connection...")
                if not MT5_INSTANCE.initialize():
                    error = MT5_INSTANCE.last_error() if hasattr(MT5_INSTANCE, 'last_error') else "Unknown error"
                    logger.warning(f"⚠️  MT5 initialize() returned False: {error}")
                    logger.info("   MT5 Terminal may not be logged in yet")
                else:
                    logger.info("   ✅ MT5 initialized successfully")
                
                # Test connection
                try:
                    account = MT5_INSTANCE.account_info()
                    if account:
                        logger.info(f"✅ MT5 connection verified - Account: {account.login}")
                    else:
                        logger.warning("⚠️  Connected but account_info() returned None")
                        logger.info("   MT5 Terminal may not be logged in yet")
                except Exception as e:
                    logger.warning(f"⚠️  Connection test failed: {e}")
                    logger.info("   MT5 Terminal may not be logged in yet")
                    
            except ConnectionRefusedError:
                logger.error("❌ Connection refused - MT5 Terminal not running or RPC server not active")
                logger.info("   Start MT5 Terminal and ensure RPC server EA is running")
                MT5_INSTANCE = None
            except Exception as e:
                logger.error(f"❌ Failed to connect to MT5: {e}")
                MT5_INSTANCE = None
                
        elif MT5_LIBRARY == "MetaTrader5":
            # Windows MetaTrader5 library - direct connection
            logger.info("🔌 Initializing MT5 (Windows library)...")
            if hasattr(mt5_module, 'initialize'):
                if mt5_module.initialize():
                    MT5_INSTANCE = mt5_module
                    logger.info("✅ MT5 initialized successfully")
                else:
                    error = mt5_module.last_error()
                    logger.error(f"❌ MT5 initialization failed: {error}")
                    MT5_INSTANCE = None
            else:
                MT5_INSTANCE = mt5_module
                logger.info("✅ MT5 library loaded")
    except Exception as e:
        logger.error(f"❌ MT5 initialization error: {e}")
        MT5_INSTANCE = None
    except Exception as e:
        logger.error(f"❌ MT5 initialization error: {e}")
        MT5_INSTANCE = None
        return
    
@app.on_event("shutdown")
async def shutdown():
    """Shutdown MT5"""
    global MT5_INSTANCE
    if MT5_INSTANCE and hasattr(MT5_INSTANCE, 'shutdown'):
        MT5_INSTANCE.shutdown()
        logger.info("MT5 shut down")
    MT5_INSTANCE = None

# Helper function to get MT5 instance or raise error
def get_mt5():
    """Get MT5 instance, raise error if not available"""
    if not MT5_AVAILABLE or MT5_INSTANCE is None:
        raise HTTPException(status_code=503, detail="MT5 not connected. Ensure MT5 Terminal is running with RPC server active.")
    return MT5_INSTANCE

# Helper to get MT5 constants (for timeframe, order types, etc.)
def get_mt5_const(name):
    """Get MT5 constant by name"""
    if MT5_LIBRARY == "mt5linux":
        # Constants are on the class
        return getattr(MetaTrader5, name, None)
    elif MT5_LIBRARY == "MetaTrader5":
        return getattr(mt5_module, name, None)
    return None

# ============ HEALTH & INFO ============

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "MT5 API Bridge",
        "version": "1.0.0",
        "mt5_available": MT5_AVAILABLE,
        "mt5_library": MT5_LIBRARY,
        "supabase_available": SUPABASE_AVAILABLE,
        "docs": "/docs"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        mt5_connected = False
        account_info = None
        
        if MT5_AVAILABLE and MT5_INSTANCE:
            try:
                account_info = MT5_INSTANCE.account_info()
                mt5_connected = account_info is not None
            except:
                mt5_connected = False
                account_info = None
        else:
            mt5_connected = False
            account_info = None
        
        return {
            "status": "healthy" if mt5_connected else "degraded",
            "mt5_available": MT5_AVAILABLE,
            "mt5_connected": mt5_connected,
            "mt5_library": MT5_LIBRARY,
            "supabase_available": SUPABASE_AVAILABLE,
            "account": account_info.login if account_info else None,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        }

# ============ ACCOUNT ENDPOINTS ============

@app.post("/api/v1/accounts/connect")
async def connect_account(
    request: ConnectRequest,
    user: dict = Depends(verify_token)
):
    """Connect to MT5 account
    
    Note: For mt5linux, MT5 Terminal must already be logged in.
    This endpoint verifies the connection and returns account info.
    """
    mt5 = get_mt5()
    
    try:
        # For mt5linux, login is done in MT5 Terminal, not via API
        # Just verify connection and get account info
        account_info = mt5.account_info()
        
        if account_info is None:
            raise HTTPException(
                status_code=400,
                detail="Not connected to MT5. Please log in to MT5 Terminal first."
            )
        
        # Verify login matches (if mt5linux supports login method)
        if hasattr(mt5, 'login'):
            # Windows MetaTrader5 library - can login programmatically
            authorized = mt5.login(
                request.login,
                password=request.password,
                server=request.server
            )
            
            if not authorized:
                error = mt5.last_error() if hasattr(mt5, 'last_error') else "Login failed"
                raise HTTPException(
                    status_code=400,
                    detail=f"Login failed: {error}"
                )
            account_info = mt5.account_info()
        
        return {
            "success": True,
            "account": {
                "login": account_info.login,
                "balance": float(account_info.balance),
                "equity": float(account_info.equity),
                "margin": float(account_info.margin),
                "free_margin": float(account_info.margin_free),
                "server": account_info.server,
                "currency": account_info.currency
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Connection error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/account/info")
async def get_account_info(user: dict = Depends(verify_token)):
    """Get account information"""
    mt5 = get_mt5()
    
    try:
        account_info = mt5.account_info()
        if account_info is None:
            raise HTTPException(status_code=404, detail="Not connected to MT5")
        
        return {
            "login": account_info.login,
            "balance": float(account_info.balance),
            "equity": float(account_info.equity),
            "margin": float(account_info.margin),
            "free_margin": float(account_info.margin_free),
            "margin_level": float(account_info.margin_level or 0),
            "profit": float(account_info.profit),
            "server": account_info.server,
            "currency": account_info.currency,
            "leverage": account_info.leverage,
            "company": account_info.company
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ============ MARKET DATA ENDPOINTS ============

@app.get("/api/v1/market-data/{symbol}")
async def get_historical_data(
    symbol: str,
    timeframe: str = Query("H1", description="M1, M5, M15, M30, H1, H4, D1, W1, MN1"),
    bars: int = Query(100, ge=1, le=10000),
    user: dict = Depends(verify_token)
):
    """Get historical market data"""
    mt5 = get_mt5()
    
    try:
        # Map timeframe - get constants from MT5
        timeframe_map = {
            "M1": get_mt5_const("TIMEFRAME_M1"),
            "M5": get_mt5_const("TIMEFRAME_M5"),
            "M15": get_mt5_const("TIMEFRAME_M15"),
            "M30": get_mt5_const("TIMEFRAME_M30"),
            "H1": get_mt5_const("TIMEFRAME_H1"),
            "H4": get_mt5_const("TIMEFRAME_H4"),
            "D1": get_mt5_const("TIMEFRAME_D1"),
            "W1": get_mt5_const("TIMEFRAME_W1"),
            "MN1": get_mt5_const("TIMEFRAME_MN1")
        }
        
        mt5_timeframe = timeframe_map.get(timeframe.upper())
        if not mt5_timeframe:
            raise HTTPException(status_code=400, detail=f"Invalid timeframe: {timeframe}")
        
        # Get data
        rates = mt5.copy_rates_from_pos(symbol, mt5_timeframe, 0, bars)
        
        if rates is None or len(rates) == 0:
            raise HTTPException(status_code=404, detail=f"No data for {symbol}")
        
        # Convert to JSON
        data = [{
            "time": int(rate[0]),
            "open": float(rate[1]),
            "high": float(rate[2]),
            "low": float(rate[3]),
            "close": float(rate[4]),
            "volume": int(rate[5])
        } for rate in rates]
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "count": len(data),
            "data": data
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/market-data/{symbol}/range")
async def get_data_range(
    symbol: str,
    timeframe: str = Query("H1"),
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    user: dict = Depends(verify_token)
):
    """Get historical data for date range"""
    mt5 = get_mt5()
    
    try:
        timeframe_map = {
            "M1": get_mt5_const("TIMEFRAME_M1"),
            "M5": get_mt5_const("TIMEFRAME_M5"),
            "M15": get_mt5_const("TIMEFRAME_M15"),
            "M30": get_mt5_const("TIMEFRAME_M30"),
            "H1": get_mt5_const("TIMEFRAME_H1"),
            "H4": get_mt5_const("TIMEFRAME_H4"),
            "D1": get_mt5_const("TIMEFRAME_D1"),
            "W1": get_mt5_const("TIMEFRAME_W1"),
            "MN1": get_mt5_const("TIMEFRAME_MN1")
        }
        
        mt5_timeframe = timeframe_map.get(timeframe.upper())
        if not mt5_timeframe:
            raise HTTPException(status_code=400, detail="Invalid timeframe")
        
        # Parse dates
        if start_date:
            start_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
            start_ts = int(start_dt.timestamp())
        else:
            start_ts = int((datetime.now() - timedelta(days=30)).timestamp())
        
        if end_date:
            end_dt = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
            end_ts = int(end_dt.timestamp())
        else:
            end_ts = int(datetime.now().timestamp())
        
        # Get data
        rates = mt5.copy_rates_range(symbol, mt5_timeframe, start_ts, end_ts)
        
        if rates is None:
            return {"symbol": symbol, "timeframe": timeframe, "count": 0, "data": []}
        
        data = [{
            "time": int(rate[0]),
            "open": float(rate[1]),
            "high": float(rate[2]),
            "low": float(rate[3]),
            "close": float(rate[4]),
            "volume": int(rate[5])
        } for rate in rates]
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "count": len(data),
            "data": data
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ============ TRADING ENDPOINTS ============

@app.post("/api/v1/trades")
async def place_order(
    request: TradeRequest,
    user: dict = Depends(verify_token)
):
    """Place a market order"""
    mt5 = get_mt5()
    
    try:
        # Get symbol info
        symbol_info = mt5.symbol_info(request.symbol)
        if symbol_info is None:
            raise HTTPException(status_code=404, detail=f"Symbol {request.symbol} not found")
        
        # Determine order type
        if request.order_type.upper() == "BUY":
            order_type_mt5 = get_mt5_const("ORDER_TYPE_BUY")
            price_exec = symbol_info.ask if request.price is None else request.price
        elif request.order_type.upper() == "SELL":
            order_type_mt5 = get_mt5_const("ORDER_TYPE_SELL")
            price_exec = symbol_info.bid if request.price is None else request.price
        else:
            raise HTTPException(status_code=400, detail="Invalid order_type")
        
        # Get filling mode constants
        ORDER_FILLING_FOK = get_mt5_const("ORDER_FILLING_FOK")  # 0
        ORDER_FILLING_IOC = get_mt5_const("ORDER_FILLING_IOC")  # 1
        ORDER_FILLING_RETURN = get_mt5_const("ORDER_FILLING_RETURN")  # 2
        TRADE_RETCODE_DONE = get_mt5_const("TRADE_RETCODE_DONE")  # 10009
        
        # Determine filling mode from symbol info
        filling_mode = None
        try:
            if hasattr(symbol_info, 'filling_mode'):
                filling_modes = symbol_info.filling_mode
                logger.info(f"Symbol {request.symbol} filling_mode: {filling_modes}")
                
                # filling_mode is a bitmask - check which modes are supported
                # filling_mode = 1 means IOC is supported
                if ORDER_FILLING_IOC is not None and (filling_modes & ORDER_FILLING_IOC):
                    filling_mode = ORDER_FILLING_IOC
                    logger.info(f"Using ORDER_FILLING_IOC (value: {ORDER_FILLING_IOC})")
                elif ORDER_FILLING_FOK is not None and (filling_modes & ORDER_FILLING_FOK):
                    filling_mode = ORDER_FILLING_FOK
                    logger.info(f"Using ORDER_FILLING_FOK (value: {ORDER_FILLING_FOK})")
                elif ORDER_FILLING_RETURN is not None and (filling_modes & ORDER_FILLING_RETURN):
                    filling_mode = ORDER_FILLING_RETURN
                    logger.info(f"Using ORDER_FILLING_RETURN (value: {ORDER_FILLING_RETURN})")
        except Exception as e:
            logger.warning(f"Error reading filling_mode: {e}")
        
        # If we couldn't determine, use IOC as default (most common for forex)
        if filling_mode is None:
            filling_mode = ORDER_FILLING_IOC if ORDER_FILLING_IOC is not None else ORDER_FILLING_RETURN
            logger.info(f"Using default filling mode: {filling_mode}")
        
        # Prepare trade request
        trade_request = {
            "action": get_mt5_const("TRADE_ACTION_DEAL"),
            "symbol": request.symbol,
            "volume": request.volume,
            "type": order_type_mt5,
            "price": price_exec,
            "sl": request.stop_loss if request.stop_loss else 0,
            "tp": request.take_profit if request.take_profit else 0,
            "deviation": 10,
            "magic": 123456,
            "comment": "API Trade",
            "type_time": get_mt5_const("ORDER_TIME_GTC"),
            "type_filling": filling_mode,
        }
        
        logger.info(f"Sending order: symbol={request.symbol}, type={request.order_type}, volume={request.volume}, filling_mode={filling_mode}")
        
        # Send order
        result = mt5.order_send(trade_request)
        
        if result is None:
            error_msg = mt5.last_error() if hasattr(mt5, 'last_error') else "Order send returned None"
            logger.error(f"Order send failed: {error_msg}")
            raise HTTPException(status_code=500, detail=f"Order send failed: {error_msg}")
        
        if result.retcode != TRADE_RETCODE_DONE:
            error_msg = result.comment if hasattr(result, 'comment') else f"Error code: {result.retcode}"
            logger.error(f"Order failed: {error_msg} (code: {result.retcode})")
            raise HTTPException(
                status_code=400,
                detail=f"Order failed: {error_msg} (code: {result.retcode})"
            )
        
        return {
            "success": True,
            "ticket": result.order,
            "price": float(result.price),
            "volume": float(result.volume),
            "symbol": request.symbol,
            "type": request.order_type
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/positions")
async def get_positions(user: dict = Depends(verify_token)):
    """Get all open positions"""
    mt5 = get_mt5()
    
    try:
        positions = mt5.positions_get()
        
        if positions is None:
            return {"positions": []}
        
        ORDER_TYPE_BUY = get_mt5_const("ORDER_TYPE_BUY")
        result = [{
            "ticket": pos.ticket,
            "symbol": pos.symbol,
            "type": "buy" if pos.type == ORDER_TYPE_BUY else "sell",
            "volume": float(pos.volume),
            "price_open": float(pos.price_open),
            "price_current": float(pos.price_current),
            "profit": float(pos.profit),
            "sl": float(pos.sl) if pos.sl > 0 else None,
            "tp": float(pos.tp) if pos.tp > 0 else None,
            "magic": pos.magic
        } for pos in positions]
        
        return {"positions": result}
    except Exception as e:
        logger.error(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/v1/positions/{ticket}")
async def close_position(ticket: int, user: dict = Depends(verify_token)):
    """Close a position"""
    mt5 = get_mt5()
    
    try:
        position = mt5.positions_get(ticket=ticket)
        if position is None or len(position) == 0:
            raise HTTPException(status_code=404, detail="Position not found")
        
        pos = position[0]
        ORDER_TYPE_BUY = get_mt5_const("ORDER_TYPE_BUY")
        ORDER_TYPE_SELL = get_mt5_const("ORDER_TYPE_SELL")
        close_type = ORDER_TYPE_SELL if pos.type == ORDER_TYPE_BUY else ORDER_TYPE_BUY
        
        symbol_info = mt5.symbol_info(pos.symbol)
        if symbol_info is None:
            raise HTTPException(status_code=404, detail="Symbol info not available")
        
        close_price = symbol_info.bid if close_type == ORDER_TYPE_SELL else symbol_info.ask
        
        # Get symbol info to determine filling mode
        symbol_info = mt5.symbol_info(pos.symbol)
        filling_mode = None
        if symbol_info:
            filling_modes = symbol_info.filling_mode
            ORDER_FILLING_FOK = get_mt5_const("ORDER_FILLING_FOK")
            ORDER_FILLING_IOC = get_mt5_const("ORDER_FILLING_IOC")
            ORDER_FILLING_RETURN = get_mt5_const("ORDER_FILLING_RETURN")
            
            if filling_modes & ORDER_FILLING_FOK:
                filling_mode = ORDER_FILLING_FOK
            elif filling_modes & ORDER_FILLING_IOC:
                filling_mode = ORDER_FILLING_IOC
            elif filling_modes & ORDER_FILLING_RETURN:
                filling_mode = ORDER_FILLING_RETURN
            else:
                filling_mode = ORDER_FILLING_RETURN
        else:
            filling_mode = get_mt5_const("ORDER_FILLING_RETURN")
        
        request = {
            "action": get_mt5_const("TRADE_ACTION_DEAL"),
            "symbol": pos.symbol,
            "volume": pos.volume,
            "type": close_type,
            "position": pos.ticket,
            "price": close_price,
            "deviation": 10,
            "magic": pos.magic,
            "comment": "Close Position",
            "type_time": get_mt5_const("ORDER_TIME_GTC"),
            "type_filling": filling_mode,
        }
        
        result = mt5.order_send(request)
        
        if result.retcode != get_mt5_const("TRADE_RETCODE_DONE"):
            raise HTTPException(status_code=400, detail=f"Close failed: {result.comment}")
        
        return {
            "success": True,
            "closed_ticket": pos.ticket,
            "price": float(result.price),
            "volume": float(result.volume)
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ============ SYMBOLS ============

@app.get("/api/v1/symbols")
async def get_symbols(user: dict = Depends(verify_token)):
    """Get all available symbols"""
    mt5 = get_mt5()
    
    try:
        symbols = mt5.symbols_get()
        
        if symbols is None:
            return {"symbols": []}
        
        result = [{
            "name": s.name,
            "description": s.description,
            "currency_base": s.currency_base,
            "currency_profit": s.currency_profit,
            "digits": s.digits,
            "spread": s.spread,
            "volume_min": float(s.volume_min),
            "volume_max": float(s.volume_max)
        } for s in symbols]
        
        return {"symbols": result}
    except Exception as e:
        logger.error(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8001"))
    uvicorn.run(app, host="0.0.0.0", port=port)

