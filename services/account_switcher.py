import logging
import threading
import signal
from typing import Dict, Optional

from fastapi import HTTPException, status

from services.account_manager import decrypt_password

logger = logging.getLogger(__name__)

_LOCK = threading.Lock()
_ACTIVE_ACCOUNT_BY_USER: Dict[str, str] = {}
_CURRENT_LOGIN: Optional[str] = None


def get_active_account_id(user_id: str) -> Optional[str]:
    with _LOCK:
        return _ACTIVE_ACCOUNT_BY_USER.get(user_id)


def set_active_account_id(user_id: str, account_id: str):
    with _LOCK:
        _ACTIVE_ACCOUNT_BY_USER[user_id] = account_id


def ensure_account_session(
    user_id: str,
    account: dict,
    mt5_module,
):
    """
    Ensure the MT5 terminal is logged into the desired account.
    Performs a login if necessary and caches the active account per user.
    """
    global _CURRENT_LOGIN

    if not mt5_module:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="MT5 module not initialized",
        )

    desired_login = str(account["login"])
    server = account["server"]
    encrypted_password = account.get("encrypted_password")
    password = decrypt_password(encrypted_password) if encrypted_password else None

    with _LOCK:
        info = None
        try:
            # Add timeout to prevent hanging - use signal-based timeout
            import signal
            
            def timeout_handler(signum, frame):
                raise TimeoutError("MT5 account_info() timed out")
            
            # Set alarm for 10 seconds
            signal.signal(signal.SIGALRM, timeout_handler)
            signal.alarm(10)
            
            try:
                info = mt5_module.account_info()
            except TimeoutError:
                logger.warning("MT5 account_info() timed out after 10s")
                info = None
            finally:
                signal.alarm(0)  # Cancel alarm
        except Exception as exc:
            logger.warning("Failed to fetch MT5 account info: %s", exc)
            info = None

        if info and str(info.login) == desired_login:
            _CURRENT_LOGIN = desired_login
            _ACTIVE_ACCOUNT_BY_USER[user_id] = account["id"]
            return

        if not hasattr(mt5_module, "login"):
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="MT5 library does not support programmatic login on this platform",
            )

        if not password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Stored account is missing credentials",
            )

        logger.info("Switching MT5 session to account %s (%s)", desired_login, server)
        
        # Add timeout to prevent hanging - use signal-based timeout
        import signal
        
        def timeout_handler(signum, frame):
            raise TimeoutError("MT5 login() timed out")
        
        # Set alarm for 30 seconds
        signal.signal(signal.SIGALRM, timeout_handler)
        signal.alarm(30)
        
        try:
            authorized = mt5_module.login(
                login=int(desired_login),
                password=password,
                server=server,
            )
        except TimeoutError:
            logger.error("MT5 login() timed out after 30s for login=%s, server=%s", desired_login, server)
            signal.alarm(0)  # Cancel alarm
            raise HTTPException(
                status_code=status.HTTP_408_REQUEST_TIMEOUT,
                detail=f"MT5 login timed out. The server may be unreachable or the server name may be incorrect.",
            )
        except Exception as exc:
            logger.error("MT5 login error: %s", exc)
            signal.alarm(0)  # Cancel alarm
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"MT5 login error: {str(exc)}",
            )
        finally:
            signal.alarm(0)  # Cancel alarm
        
        if not authorized:
            error = getattr(mt5_module, "last_error", lambda: "Unknown error")()
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"MT5 login failed: {error}",
            )

        _CURRENT_LOGIN = desired_login
        _ACTIVE_ACCOUNT_BY_USER[user_id] = account["id"]


def clear_account_cache(account_id: str):
    with _LOCK:
        to_remove = [user for user, acct in _ACTIVE_ACCOUNT_BY_USER.items() if acct == account_id]
        for user in to_remove:
            _ACTIVE_ACCOUNT_BY_USER.pop(user, None)





