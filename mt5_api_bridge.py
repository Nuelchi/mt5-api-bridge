#!/usr/bin/env python3
"""
MT5 API Bridge - Standalone FastAPI Server
Web API for MT5 trading and data access on Linux VPS
Uses Supabase JWT authentication (same as Trainflow backend)
"""

from fastapi import FastAPI, Depends, HTTPException, Query, status, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta
import logging
import os
import jwt
import time
import asyncio
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FutureTimeoutError

# Supabase authentication (same as backend)
from supabase import Client

from database.supabase_client import get_supabase_client, is_supabase_available
from models.account_models import (
    AccountConnectRequest,
    AccountListResponse,
    AccountResponse,
    AccountUpdateRequest,
    SwitchAccountResponse,
)
from services import account_manager, account_switcher
from services.trade_journal_logger import log_closed_position_to_journal

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

supabase_client: Optional[Client] = get_supabase_client()
SUPABASE_AVAILABLE = is_supabase_available()

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


def _require_account(user_id: str, account_id: Optional[str] = None) -> AccountResponse:
    """
    Fetch the requested account for a user, defaulting to the cached
    active account or the user's default account.
    """
    if account_id:
        return account_manager.get_account(user_id, account_id)

    cached_id = account_switcher.get_active_account_id(user_id)
    if cached_id:
        return account_manager.get_account(user_id, cached_id)

    default_account = account_manager.get_default_account(user_id)
    if default_account:
        return default_account

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="No MT5 account connected. Use /api/v1/accounts/connect first.",
    )


def _ensure_account_session(user_id: str, account: AccountResponse, mt5_instance=None):
    mt5_instance = mt5_instance or get_mt5()
    account_switcher.ensure_account_session(user_id, account.dict(), mt5_instance)

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

@app.post("/api/v1/accounts/connect", response_model=AccountResponse)
async def connect_account(
    request: AccountConnectRequest,
    user: dict = Depends(verify_token),
):
    """
    Connect (or add) an MT5 account for the authenticated user.
    Verifies the credentials against MT5, stores them in Supabase
    (with backend-managed encryption), and sets the account as active.
    """
    logger.info(f"📥 Received connection request: login={request.login}, server={request.server}, user_id={user.get('user_id', 'unknown')}")
    mt5 = get_mt5()
    user_id = user["user_id"]

    if not hasattr(mt5, "login"):
        raise HTTPException(
            status_code=503,
            detail="MT5 library does not allow programmatic login on this platform",
        )

    try:
        logger.info(f"🔐 Attempting to connect account: login={request.login}, server={request.server}")
        try:
            login_id = int(request.login)
        except ValueError:
            logger.error(f"Invalid login format: {request.login}")
            raise HTTPException(
                status_code=400,
                detail="MT5 login must be numeric for automation. Please verify account number.",
            )

        # Run login in executor with timeout to prevent hanging
        logger.info(f"Starting MT5 login attempt for login={login_id}, server={request.server}")
        executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="mt5-login")
        
        # Use shorter timeout for non-MetaQuotes servers (they tend to be slower/unreliable)
        is_metaquotes = "MetaQuotes" in request.server
        login_timeout = 15.0 if is_metaquotes else 30.0
        logger.info(f"Using {login_timeout}s timeout for server {request.server}")
        
        def login_with_timeout():
            logger.info(f"Executing mt5.login() in thread for login={login_id}, server={request.server}")
            try:
                # Set a signal-based timeout as backup (if RPyC blocks)
                import signal
                
                def timeout_handler(signum, frame):
                    logger.error(f"Signal timeout triggered for login={login_id}, server={request.server}")
                    raise TimeoutError("Login operation timed out")
                
                # Set alarm for backup timeout (only works on Unix)
                if hasattr(signal, 'SIGALRM'):
                    signal.signal(signal.SIGALRM, timeout_handler)
                    signal.alarm(int(login_timeout + 5))  # 5 seconds buffer
                
                try:
                    result = mt5.login(
                        login_id,
                        password=request.password,
                        server=request.server,
                    )
                    logger.info(f"mt5.login() returned: {result}")
                    return result
                finally:
                    # Cancel alarm
                    if hasattr(signal, 'SIGALRM'):
                        signal.alarm(0)
            except TimeoutError:
                logger.error(f"Timeout in mt5.login() thread for login={login_id}, server={request.server}")
                raise
            except Exception as e:
                logger.error(f"Exception in mt5.login() thread: {e}", exc_info=True)
                raise
        
        try:
            logger.info(f"Waiting for login with {login_timeout}s timeout...")
            try:
                loop = asyncio.get_event_loop()
            except RuntimeError:
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
            
            authorized = await asyncio.wait_for(
                loop.run_in_executor(executor, login_with_timeout),
                timeout=login_timeout
            )
            logger.info(f"Login attempt completed: authorized={authorized}")
        except asyncio.TimeoutError:
            logger.error(f"⏱️ Login timeout after {login_timeout}s for login={login_id}, server={request.server}")
            executor.shutdown(wait=False, cancel_futures=True)
            raise HTTPException(
                status_code=408,
                detail=f"Login timeout: Unable to connect to server '{request.server}' after {login_timeout} seconds. The server may be unreachable, the server name may be incorrect, or there may be network issues. Please verify the server name matches exactly what you see in MT5 terminal."
            )
        except TimeoutError:
            logger.error(f"⏱️ Signal timeout for login={login_id}, server={request.server}")
            executor.shutdown(wait=False, cancel_futures=True)
            raise HTTPException(
                status_code=408,
                detail=f"Login timeout: Unable to connect to server '{request.server}'. The server may be unreachable or the server name may be incorrect."
            )
        except Exception as e:
            logger.error(f"Login error for login={login_id}, server={request.server}: {e}", exc_info=True)
            executor.shutdown(wait=False, cancel_futures=True)
            raise HTTPException(
                status_code=500,
                detail=f"Login error: {str(e)}"
            )
        finally:
            try:
                executor.shutdown(wait=True, timeout=5)
            except Exception:
                pass
        
        if not authorized:
            error = mt5.last_error() if hasattr(mt5, "last_error") else "Login failed"
            error_msg = f"Login failed: {error}"
            # Provide more helpful error messages
            if "invalid" in str(error).lower() or "wrong" in str(error).lower():
                error_msg += f" Please verify login ({login_id}), password, and server name ('{request.server}') are correct."
            raise HTTPException(status_code=400, detail=error_msg)

        account_info = mt5.account_info()
        if not account_info:
            raise HTTPException(
                status_code=503,
                detail="Connected to MT5 but account information is unavailable",
            )

        account = account_manager.create_or_update_account(user_id, request)
        # refresh session cache
        _ensure_account_session(user_id, account, mt5_instance=mt5)

        # enrich response with latest balances
        enriched = account.copy(
            update={
                "balance": float(account_info.balance),
                "equity": float(account_info.equity),
            }
        )
        return enriched
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Connection error: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc))

# Common MT5 broker servers list for autocomplete
COMMON_MT5_SERVERS = [
    # MetaQuotes (Demo)
    "MetaQuotes-Demo",
    "MetaQuotes-Software-Demo",
    
    # Popular Brokers - Demo
    "ICMarkets-Demo",
    "ICMarkets-Demo02",
    "ICMarkets-Demo03",
    "ICMarkets-Live",
    "ICMarkets-Live02",
    "ICMarkets-Live03",
    
    "FXTM-Demo",
    "FXTM-Demo-Server",
    "FXTM-Live",
    "FXTM-Live-Server",
    
    "XMGlobal-Demo",
    "XMGlobal-Demo-1",
    "XMGlobal-Demo-2",
    "XMGlobal-Demo-3",
    "XMGlobal-Demo-4",
    "XMGlobal-Demo-5",
    "XMGlobal-Live",
    "XMGlobal-Live-1",
    "XMGlobal-Live-2",
    "XMGlobal-Live-3",
    "XMGlobal-Live-4",
    "XMGlobal-Live-5",
    
    "Exness-Real",
    "Exness-Demo",
    "Exness-Real-1",
    "Exness-Real-2",
    "Exness-Demo-1",
    "Exness-Demo-2",
    
    "ForexTime-Demo",
    "ForexTime-Demo-Server",
    "ForexTime-Live",
    "ForexTime-Live-Server",
    "ForexTime-Pro",
    "ForexTime-Pro-Server",
    
    "HFMarkets-Demo",
    "HFMarkets-Demo-Server",
    "HFMarkets-Live",
    "HFMarkets-Live-Server",
    "HFMarketsGlobal-Demo",
    "HFMarketsGlobal-Live",
    "HFMarketsGlobal-Demo-Server",
    "HFMarketsGlobal-Live-Server",
    "HFM-Demo",
    "HFM-Live",
    "HFMGlobal-Demo",
    "HFMGlobal-Live",
    
    "Pepperstone-Demo",
    "Pepperstone-Demo-Server",
    "Pepperstone-Live",
    "Pepperstone-Live-Server",
    
    "AvaTrade-Demo",
    "AvaTrade-Demo-Server",
    "AvaTrade-Live",
    "AvaTrade-Live-Server",
    
    "OANDA-Demo",
    "OANDA-Live",
    "OANDA-v20-Demo",
    "OANDA-v20-Live",
    
    "AdmiralMarkets-Demo",
    "AdmiralMarkets-Demo-Server",
    "AdmiralMarkets-Live",
    "AdmiralMarkets-Live-Server",
    
    "FXCM-Demo",
    "FXCM-Live",
    
    "Alpari-Demo",
    "Alpari-Live",
    "Alpari-International-Demo",
    "Alpari-International-Live",
    
    "RoboForex-Demo",
    "RoboForex-Live",
    "RoboForex-Pro",
    
    "Tickmill-Demo",
    "Tickmill-Live",
    
    "Vantage-Demo",
    "Vantage-Live",
    "VantageFX-Demo",
    "VantageFX-Live",
    
    "OctaFX-Demo",
    "OctaFX-Live",
    
    "FBS-Demo",
    "FBS-Live",
    
    "JustForex-Demo",
    "JustForex-Live",
    
    "InstaForex-Demo",
    "InstaForex-Live",
    
    "HotForex-Demo",
    "HotForex-Live",
    
    "FXOpen-Demo",
    "FXOpen-Live",
    
    "LiteForex-Demo",
    "LiteForex-Live",
    
    "NordFX-Demo",
    "NordFX-Live",
    
    "AMarkets-Demo",
    "AMarkets-Live",
    
    "FXDD-Demo",
    "FXDD-Live",
    
    "FXPrimus-Demo",
    "FXPrimus-Live",
    
    "IronFX-Demo",
    "IronFX-Live",
    
    "TradersWay-Demo",
    "TradersWay-Live",
    
    "Tradeview-Demo",
    "Tradeview-Live",
    
    "Axi-Demo",
    "Axi-Live",
    
    "FP Markets-Demo",
    "FP Markets-Live",
    
    "ThinkMarkets-Demo",
    "ThinkMarkets-Live",
    
    "VPSForex-Demo",
    "VPSForex-Live",
]

@app.get("/api/v1/servers/suggest")
async def suggest_servers(
    query: str = Query("", min_length=0, max_length=100),
    limit: int = Query(20, ge=1, le=50),
    user: dict = Depends(verify_token)
):
    """
    Suggest MT5 server names based on user input (autocomplete).
    Returns a filtered list of common MT5 broker servers.
    """
    query_lower = query.lower().strip()
    
    if not query_lower:
        # Return most common servers if no query
        suggestions = COMMON_MT5_SERVERS[:limit]
    else:
        # Filter servers that match the query
        suggestions = [
            server for server in COMMON_MT5_SERVERS
            if query_lower in server.lower()
        ][:limit]
    
    return {
        "suggestions": suggestions,
        "count": len(suggestions),
        "query": query
    }

@app.post("/api/v1/servers/verify")
async def verify_server(
    server: str = Query(..., min_length=1, max_length=100),
    user: dict = Depends(verify_token)
):
    """
    Verify if an MT5 server is accessible (quick connectivity test).
    This helps users know if a server name is correct before attempting full login.
    Uses a very short timeout (5 seconds) to quickly test connectivity.
    """
    mt5 = get_mt5()
    
    if not hasattr(mt5, "login"):
        raise HTTPException(
            status_code=503,
            detail="MT5 library does not allow programmatic login on this platform",
        )
    
    # Use a dummy login to test server connectivity (will fail but quickly)
    # This is faster than full login and helps verify server name
    logger.info(f"🔍 Verifying server connectivity: {server}")
    
    executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="mt5-verify")
    
    def verify_connectivity():
        try:
            # Try login with invalid credentials - this will fail quickly if server is reachable
            # or timeout if server is unreachable
            result = mt5.login(
                99999999,  # Invalid login
                password="test",
                server=server,
            )
            # If we get here, server is reachable (even if login failed)
            return True
        except Exception as e:
            # Check if it's a timeout/connection error vs auth error
            error_str = str(e).lower()
            if "timeout" in error_str or "connection" in error_str or "network" in error_str:
                return False
            # Auth errors mean server is reachable
            return True
    
    try:
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
        
        # Very short timeout - just to test if server responds
        is_reachable = await asyncio.wait_for(
            loop.run_in_executor(executor, verify_connectivity),
            timeout=5.0  # 5 second timeout for quick check
        )
        
        return {
            "server": server,
            "reachable": is_reachable,
            "message": "Server is reachable" if is_reachable else "Server may be unreachable or name is incorrect"
        }
    except asyncio.TimeoutError:
        logger.warning(f"⏱️ Server verification timeout for {server}")
        executor.shutdown(wait=False, cancel_futures=True)
        return {
            "server": server,
            "reachable": False,
            "message": "Server verification timed out - server may be unreachable or name is incorrect"
        }
    except Exception as e:
        logger.error(f"Server verification error for {server}: {e}", exc_info=True)
        executor.shutdown(wait=False, cancel_futures=True)
        return {
            "server": server,
            "reachable": False,
            "message": f"Verification error: {str(e)}"
        }
    finally:
        try:
            executor.shutdown(wait=True, timeout=2)
        except Exception:
            pass

@app.get("/api/v1/account/info")
async def get_account_info(user: dict = Depends(verify_token)):
    """Get account information"""
    mt5 = get_mt5()
    account = _require_account(user["user_id"])
    _ensure_account_session(user["user_id"], account, mt5)
    
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


@app.get("/api/v1/accounts", response_model=AccountListResponse)
async def list_accounts_endpoint(user: dict = Depends(verify_token)):
    accounts = account_manager.list_accounts(user["user_id"])
    return AccountListResponse(accounts=accounts)


@app.get("/api/v1/accounts/current", response_model=AccountResponse)
async def get_current_account(user: dict = Depends(verify_token)):
    account = _require_account(user["user_id"])
    mt5 = get_mt5()
    _ensure_account_session(user["user_id"], account, mt5)
    info = mt5.account_info()
    if info:
        account = account.copy(
            update={
                "balance": float(info.balance),
                "equity": float(info.equity),
            }
        )
    return account


@app.post("/api/v1/accounts/{account_id}/switch", response_model=SwitchAccountResponse)
async def switch_account(account_id: str, user: dict = Depends(verify_token)):
    account = account_manager.get_account(user["user_id"], account_id)
    mt5 = get_mt5()
    _ensure_account_session(user["user_id"], account, mt5)
    info = mt5.account_info()
    if info:
        account = account.copy(
            update={
                "balance": float(info.balance),
                "equity": float(info.equity),
            }
        )
    return SwitchAccountResponse(success=True, account=account)


@app.put("/api/v1/accounts/{account_id}", response_model=AccountResponse)
async def update_account_endpoint(
    account_id: str,
    request: AccountUpdateRequest,
    user: dict = Depends(verify_token),
):
    account = account_manager.update_account(user["user_id"], account_id, request)
    return account


@app.delete("/api/v1/accounts/{account_id}")
async def delete_account_endpoint(account_id: str, user: dict = Depends(verify_token)):
    account_manager.delete_account(user["user_id"], account_id)
    account_switcher.clear_account_cache(account_id)
    return {"success": True}

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
    account = _require_account(user["user_id"])
    _ensure_account_session(user["user_id"], account, mt5)
    
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
    account = _require_account(user["user_id"])
    _ensure_account_session(user["user_id"], account, mt5)
    
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
    account = _require_account(user["user_id"])
    _ensure_account_session(user["user_id"], account, mt5)
    
    try:
        # Get symbol info
        symbol_info = mt5.symbol_info(request.symbol)
        if symbol_info is None:
            raise HTTPException(status_code=404, detail=f"Symbol {request.symbol} not found")
        
        # Get current tick (like working examples do)
        tick = mt5.symbol_info_tick(request.symbol)
        if tick is None:
            raise HTTPException(status_code=404, detail=f"Failed to get tick for {request.symbol}")
        
        # Determine order type and price
        if request.order_type.upper() == "BUY":
            order_type_mt5 = get_mt5_const("ORDER_TYPE_BUY")
            price_exec = request.price if request.price is not None else tick.ask
        elif request.order_type.upper() == "SELL":
            order_type_mt5 = get_mt5_const("ORDER_TYPE_SELL")
            price_exec = request.price if request.price is not None else tick.bid
        else:
            raise HTTPException(status_code=400, detail="Invalid order_type")
        
        # Get filling mode constants - use numeric values directly for RPyC compatibility
        ORDER_FILLING_FOK = 0
        ORDER_FILLING_IOC = 1
        ORDER_FILLING_RETURN = 2
        TRADE_RETCODE_DONE = 10009
        TRADE_RETCODE_AUTOTRADING_DISABLED = 10027
        
        # Determine filling mode from symbol info
        # filling_mode is a bitmask - check which modes are supported
        filling_mode = None
        try:
            if hasattr(symbol_info, 'filling_mode'):
                filling_modes = symbol_info.filling_mode
                logger.info(f"Symbol {request.symbol} filling_mode: {filling_modes}")
                
                # Check which modes are supported (bitwise AND)
                if (filling_modes & ORDER_FILLING_IOC):
                    filling_mode = ORDER_FILLING_IOC
                    logger.info(f"Using ORDER_FILLING_IOC (value: {ORDER_FILLING_IOC})")
                elif (filling_modes & ORDER_FILLING_FOK):
                    filling_mode = ORDER_FILLING_FOK
                    logger.info(f"Using ORDER_FILLING_FOK (value: {ORDER_FILLING_FOK})")
                elif (filling_modes & ORDER_FILLING_RETURN):
                    filling_mode = ORDER_FILLING_RETURN
                    logger.info(f"Using ORDER_FILLING_RETURN (value: {ORDER_FILLING_RETURN})")
        except Exception as e:
            logger.warning(f"Error reading filling_mode: {e}")
        
        # Try detected filling mode first, then fallbacks
        # Always try multiple modes in case the detected one doesn't work
        filling_modes_to_try = []
        if filling_mode is not None:
            # Start with detected mode
            filling_modes_to_try.append(filling_mode)
        
        # Always try without type_filling (some brokers handle it automatically)
        if None not in filling_modes_to_try:
            filling_modes_to_try.append(None)
        
        # Try other standard modes as fallbacks
        for mode in [ORDER_FILLING_RETURN, ORDER_FILLING_IOC, ORDER_FILLING_FOK]:
            if mode not in filling_modes_to_try:
                filling_modes_to_try.append(mode)
        
        # Try each filling mode until one works
        result = None
        last_error = None
        
        for try_filling_mode in filling_modes_to_try:
            try:
                # Build request dict exactly like working examples
                trade_request = {
                    "action": get_mt5_const("TRADE_ACTION_DEAL"),
                    "symbol": request.symbol,
                    "volume": float(request.volume),
                    "type": order_type_mt5,
                    "price": float(price_exec),
                    "deviation": 10,
                    "magic": 123456,
                    "comment": "API Trade",
                    "type_time": get_mt5_const("ORDER_TIME_GTC"),
                }
                
                # Add SL/TP if provided
                if request.stop_loss:
                    trade_request["sl"] = float(request.stop_loss)
                if request.take_profit:
                    trade_request["tp"] = float(request.take_profit)
                
                # Only add type_filling if we have a value
                if try_filling_mode is not None:
                    trade_request["type_filling"] = try_filling_mode
                
                logger.info(f"Trying order: symbol={request.symbol}, type={request.order_type}, volume={request.volume}, price={price_exec}, filling_mode={try_filling_mode or 'auto'}")
                
                # Send order
                result = mt5.order_send(trade_request)
                
                if result is None:
                    last_error = "Order send returned None"
                    logger.warning(f"Order send returned None with filling_mode={try_filling_mode or 'auto'}, trying next...")
                    continue
                
                if result.retcode == TRADE_RETCODE_DONE:
                    logger.info(f"Order succeeded with filling_mode={try_filling_mode or 'auto'}")
                    break
                else:
                    # Special handling for AutoTrading disabled (10027)
                    if result.retcode == TRADE_RETCODE_AUTOTRADING_DISABLED:
                        error_msg = "AutoTrading is disabled in MT5 Terminal. Please enable AutoTrading in MT5 Terminal (Tools → Options → Expert Advisors → Allow automated trading) to place trades via API."
                        raise HTTPException(
                            status_code=400,
                            detail=error_msg
                        )
                    # If it's not a filling mode error (10030), fail immediately
                    if result.retcode != 10030:
                        error_msg = result.comment if hasattr(result, 'comment') else f"Error code: {result.retcode}"
                        raise HTTPException(
                            status_code=400,
                            detail=f"Order failed: {error_msg} (code: {result.retcode})"
                        )
                    last_error = result.comment if hasattr(result, 'comment') else f"Error code: {result.retcode}"
                    logger.warning(f"Filling mode {try_filling_mode or 'auto'} failed: {last_error}, trying next...")
            except HTTPException:
                raise
            except Exception as e:
                last_error = str(e)
                logger.warning(f"Error with filling_mode={try_filling_mode or 'auto'}: {e}, trying next...")
        
        if result is None or result.retcode != TRADE_RETCODE_DONE:
            error_msg = last_error or "All filling modes failed"
            raise HTTPException(
                status_code=400,
                detail=f"Order failed: {error_msg} (code: {result.retcode if result else 'unknown'})"
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
    account = _require_account(user["user_id"])
    _ensure_account_session(user["user_id"], account, mt5)
    
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


@app.get("/api/v1/trades/history")
async def get_trade_history(
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = None,
    limit: int = Query(100, ge=1, le=1000),
    user: dict = Depends(verify_token)
):
    """Get trade history (closed deals) from MT5"""
    mt5 = get_mt5()
    account = _require_account(user["user_id"])
    _ensure_account_session(user["user_id"], account, mt5)
    
    try:
        # Parse dates
        if start_date:
            start_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
            start_ts = int(start_dt.timestamp())
        else:
            # Default to last 30 days
            start_ts = int((datetime.now() - timedelta(days=30)).timestamp())
        
        if end_date:
            end_dt = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
            end_ts = int(end_dt.timestamp())
        else:
            end_ts = int(datetime.now().timestamp())
        
        # Get deals from MT5 history
        # DEAL_ENTRY_IN = 0 (entry deal)
        # DEAL_ENTRY_OUT = 1 (exit deal)
        DEAL_ENTRY_OUT = 1
        deals = mt5.history_deals_get(start_ts, end_ts)
        
        if deals is None or len(deals) == 0:
            return {"trades": [], "count": 0}
        
        # Group deals by position_id to match entry/exit pairs
        position_deals = {}
        for deal in deals:
            pos_id = deal.position_id
            if pos_id not in position_deals:
                position_deals[pos_id] = {"entry": None, "exit": None}
            
            if deal.entry == 0:  # Entry deal
                position_deals[pos_id]["entry"] = deal
            elif deal.entry == DEAL_ENTRY_OUT:  # Exit deal
                position_deals[pos_id]["exit"] = deal
        
        # Build trades from complete entry/exit pairs
        trades = []
        ORDER_TYPE_BUY = get_mt5_const("ORDER_TYPE_BUY")
        
        for pos_id, deals_pair in position_deals.items():
            entry_deal = deals_pair.get("entry")
            exit_deal = deals_pair.get("exit")
            
            # Only include trades with both entry and exit
            if entry_deal and exit_deal:
                trade_type = "buy" if entry_deal.type == ORDER_TYPE_BUY else "sell"
                
                # Calculate P&L percentage
                entry_price = float(entry_deal.price)
                exit_price = float(exit_deal.price)
                pnl_percent = 0.0
                if entry_price > 0:
                    if trade_type == "buy":
                        pnl_percent = ((exit_price - entry_price) / entry_price) * 100
                    else:
                        pnl_percent = ((entry_price - exit_price) / entry_price) * 100
                
                trades.append({
                    "ticket": pos_id,
                    "symbol": exit_deal.symbol,
                    "type": trade_type,
                    "volume": float(exit_deal.volume),
                    "entry_price": entry_price,
                    "exit_price": exit_price,
                    "pnl": float(exit_deal.profit),
                    "pnl_percent": pnl_percent,
                    "entry_time": datetime.fromtimestamp(entry_deal.time).isoformat(),
                    "exit_time": datetime.fromtimestamp(exit_deal.time).isoformat(),
                    "commission": float(exit_deal.commission) if hasattr(exit_deal, 'commission') else 0,
                    "swap": float(exit_deal.swap) if hasattr(exit_deal, 'swap') else 0
                })
        
        # Sort by exit time (most recent first) and limit
        trades.sort(key=lambda x: x["exit_time"], reverse=True)
        trades = trades[:limit]
        
        return {
            "trades": trades,
            "count": len(trades)
        }
    except Exception as e:
        logger.error(f"Error fetching trade history: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/api/v1/positions/{ticket}")
async def close_position(ticket: int, background_tasks: BackgroundTasks, user: dict = Depends(verify_token)):
    """Close a position"""
    mt5 = get_mt5()
    account = _require_account(user["user_id"])
    _ensure_account_session(user["user_id"], account, mt5)
    
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
        ORDER_FILLING_FOK = 0
        ORDER_FILLING_IOC = 1
        ORDER_FILLING_RETURN = 2
        TRADE_RETCODE_DONE = 10009
        TRADE_RETCODE_AUTOTRADING_DISABLED = 10027
        
        # Determine filling mode from symbol info
        filling_mode = None
        try:
            if symbol_info and hasattr(symbol_info, 'filling_mode'):
                filling_modes = symbol_info.filling_mode
                logger.info(f"Symbol {pos.symbol} filling_mode: {filling_modes}")
                
                # Check which modes are supported (bitwise AND)
                if (filling_modes & ORDER_FILLING_IOC):
                    filling_mode = ORDER_FILLING_IOC
                elif (filling_modes & ORDER_FILLING_FOK):
                    filling_mode = ORDER_FILLING_FOK
                elif (filling_modes & ORDER_FILLING_RETURN):
                    filling_mode = ORDER_FILLING_RETURN
        except Exception as e:
            logger.warning(f"Error reading filling_mode: {e}")
        
        # Try detected filling mode first, then fallbacks
        filling_modes_to_try = []
        if filling_mode is not None:
            filling_modes_to_try.append(filling_mode)
        
        # Always try without type_filling (some brokers handle it automatically)
        if None not in filling_modes_to_try:
            filling_modes_to_try.append(None)
        
        # Try other standard modes as fallbacks
        for mode in [ORDER_FILLING_RETURN, ORDER_FILLING_IOC, ORDER_FILLING_FOK]:
            if mode not in filling_modes_to_try:
                filling_modes_to_try.append(mode)
        
        # Try each filling mode until one works
        result = None
        last_error = None
        
        for try_filling_mode in filling_modes_to_try:
            try:
                request = {
                    "action": get_mt5_const("TRADE_ACTION_DEAL"),
                    "symbol": pos.symbol,
                    "volume": float(pos.volume),
                    "type": close_type,
                    "position": pos.ticket,
                    "price": float(close_price),
                    "deviation": 10,
                    "magic": pos.magic,
                    "comment": "Close Position",
                    "type_time": get_mt5_const("ORDER_TIME_GTC"),
                }
                
                # Only add type_filling if we have a value
                if try_filling_mode is not None:
                    request["type_filling"] = try_filling_mode
                
                logger.info(f"Trying to close position {pos.ticket}: symbol={pos.symbol}, filling_mode={try_filling_mode or 'auto'}")
                
                result = mt5.order_send(request)
                
                if result is None:
                    last_error = "Order send returned None"
                    logger.warning(f"Close returned None with filling_mode={try_filling_mode or 'auto'}, trying next...")
                    continue
                
                if result.retcode == TRADE_RETCODE_DONE:
                    logger.info(f"Position closed with filling_mode={try_filling_mode or 'auto'}")
                    break
                else:
                    # Special handling for AutoTrading disabled (10027)
                    if result.retcode == TRADE_RETCODE_AUTOTRADING_DISABLED:
                        error_msg = "AutoTrading is disabled in MT5 Terminal. Please enable AutoTrading in MT5 Terminal (Tools → Options → Expert Advisors → Allow automated trading) to close positions via API."
                        raise HTTPException(
                            status_code=400,
                            detail=error_msg
                        )
                    # If it's not a filling mode error (10030), fail immediately
                    if result.retcode != 10030:
                        error_msg = result.comment if hasattr(result, 'comment') else f"Error code: {result.retcode}"
                        raise HTTPException(
                            status_code=400,
                            detail=f"Close failed: {error_msg} (code: {result.retcode})"
                        )
                    last_error = result.comment if hasattr(result, 'comment') else f"Error code: {result.retcode}"
                    logger.warning(f"Filling mode {try_filling_mode or 'auto'} failed: {last_error}, trying next...")
            except HTTPException:
                raise
            except Exception as e:
                last_error = str(e)
                logger.warning(f"Error with filling_mode={try_filling_mode or 'auto'}: {e}, trying next...")
        
        if result is None or result.retcode != TRADE_RETCODE_DONE:
            error_msg = last_error or "All filling modes failed"
            raise HTTPException(
                status_code=400,
                detail=f"Close failed: {error_msg} (code: {result.retcode if result else 'unknown'})"
            )
        
        # Log to trade journal (non-blocking - don't fail if this fails)
        try:
            position_dict = {
                'ticket': pos.ticket,
                'symbol': pos.symbol,
                'type': pos.type,
                'volume': float(pos.volume),
                'price_open': float(pos.price_open),
                'price_current': float(pos.price_current),
                'profit': float(pos.profit),
                'sl': float(pos.sl) if pos.sl > 0 else 0,
                'tp': float(pos.tp) if pos.tp > 0 else 0,
                'time_open': pos.time_open
            }
            close_result_dict = {
                'price': float(result.price),
                'volume': float(result.volume),
                'ticket': result.order
            }
            
            # Get account ID for trade journal
            account_id = str(account.id) if hasattr(account, 'id') else account.get('id', '')
            
            # Log to trade journal in background (non-blocking)
            background_tasks.add_task(
                log_closed_position_to_journal,
                user_id=user["user_id"],
                account_id=account_id,
                position_data=position_dict,
                close_result=close_result_dict
            )
        except Exception as journal_error:
            logger.warning(f"Failed to log closed position to trade journal: {journal_error}")
            # Don't fail the close operation if journal logging fails
        
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
    account = _require_account(user["user_id"])
    _ensure_account_session(user["user_id"], account, mt5)
    
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

