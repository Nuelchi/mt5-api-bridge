import logging
import threading
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
            info = mt5_module.account_info()
        except Exception as exc:
            logger.warning("Failed to fetch MT5 account info: %s", exc)

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
        authorized = mt5_module.login(
            login=int(desired_login),
            password=password,
            server=server,
        )
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

