"""
Supabase-backed MT5 account storage utilities.

Passwords are encrypted/decrypted via Supabase RPC functions that already
exist in the backend (handled outside this service). This module simply
invokes those RPCs and never implements crypto locally.
"""

import logging
import os
from typing import Any, Dict, Optional

import httpx
from fastapi import HTTPException, status

from database.supabase_client import get_supabase_client
from models.account_models import (
    AccountConnectRequest,
    AccountResponse,
    AccountUpdateRequest,
)

logger = logging.getLogger(__name__)

MT5_ACCOUNTS_TABLE = "mt5_accounts"
ENCRYPT_RPC = "encrypt_password"
DECRYPT_RPC = "decrypt_password"

BACKEND_API_BASE = os.getenv("TRAINFLOW_BACKEND_URL", "").rstrip("/")
ENCRYPTION_SERVICE_KEY = os.getenv("TRAINFLOW_SERVICE_KEY")


def _require_supabase():
    client = get_supabase_client()
    if not client:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Supabase client not configured on MT5 bridge",
        )
    return client


def _run_rpc(function: str, payload: Dict[str, Any]) -> Optional[str]:
    client = _require_supabase()
    try:
        logger.debug("Calling Supabase RPC: %s with payload keys: %s", function, list(payload.keys()))
        response = client.rpc(function, payload).execute()
        if response.data:
            logger.debug("RPC %s returned data", function)
            return response.data
        else:
            logger.warning("RPC %s returned no data", function)
            return None
    except Exception as exc:
        error_str = str(exc)
        if "404" in error_str or "not found" in error_str.lower():
            logger.error("RPC %s does not exist in Supabase. Please create this function in your database.", function)
        else:
            logger.error("RPC %s failed: %s", function, exc, exc_info=True)
        return None


def _call_encryption_service(path: str, payload: Dict[str, Any]) -> Optional[str]:
    if not BACKEND_API_BASE or not ENCRYPTION_SERVICE_KEY:
        logger.debug("Encryption service not configured: BACKEND_API_BASE=%s, ENCRYPTION_SERVICE_KEY=%s", 
                    bool(BACKEND_API_BASE), bool(ENCRYPTION_SERVICE_KEY))
        return None
    url = f"{BACKEND_API_BASE}/api/v1/accounts/{path}"
    try:
        logger.debug("Calling encryption service: %s", url)
        response = httpx.post(
            url,
            json=payload,
            headers={"X-Service-Key": ENCRYPTION_SERVICE_KEY},
            timeout=10.0,
        )
        if response.status_code == 200:
            data = response.json()
            result = data.get("encrypted") if path == "encrypt" else data.get("password")
            if result:
                logger.debug("Encryption service returned result")
                return result
            else:
                logger.warning("Encryption service returned 200 but no result in response: %s", data)
        else:
            logger.warning("Encryption service responded with %s: %s", response.status_code, response.text[:500])
    except httpx.TimeoutException:
        logger.error("Encryption service request timed out after 10s: %s", url)
    except httpx.ConnectError as exc:
        logger.error("Encryption service connection failed: %s - Is the backend running at %s?", exc, BACKEND_API_BASE)
    except Exception as exc:
        logger.error("Encryption service request failed: %s", exc, exc_info=True)
    return None


def encrypt_password(password: str) -> str:
    if not password:
        raise HTTPException(status_code=400, detail="Password is required")

    encrypted = _call_encryption_service("encrypt", {"password": password})
    if encrypted:
        return encrypted

    encrypted = _run_rpc(ENCRYPT_RPC, {"password": password})
    if encrypted:
        return encrypted

    raise HTTPException(status_code=500, detail="Failed to encrypt MT5 password")


def decrypt_password(encrypted: str) -> str:
    if not encrypted:
        raise HTTPException(status_code=400, detail="Encrypted value is required")

    # Try backend encryption service first
    if BACKEND_API_BASE and ENCRYPTION_SERVICE_KEY:
        logger.info(f"Attempting to decrypt via backend service: {BACKEND_API_BASE}")
        decrypted = _call_encryption_service("decrypt", {"encrypted": encrypted})
        if decrypted:
            logger.info("Successfully decrypted via backend service")
            return decrypted
        logger.warning("Backend encryption service failed or returned no result")
    else:
        logger.warning(f"Backend encryption service not configured: BACKEND_API_BASE={bool(BACKEND_API_BASE)}, ENCRYPTION_SERVICE_KEY={'***' if ENCRYPTION_SERVICE_KEY else 'NOT SET'}")

    # Fallback to Supabase RPC
    logger.info("Attempting to decrypt via Supabase RPC")
    decrypted = _run_rpc(DECRYPT_RPC, {"encrypted": encrypted})
    if decrypted:
        logger.info("Successfully decrypted via Supabase RPC")
        return decrypted
    logger.warning("Supabase RPC decrypt_password failed or returned no result")

    # Both methods failed - provide helpful error
    error_detail = "Failed to decrypt MT5 password. "
    if not BACKEND_API_BASE or not ENCRYPTION_SERVICE_KEY:
        error_detail += "Backend encryption service not configured (TRAINFLOW_BACKEND_URL or TRAINFLOW_SERVICE_KEY missing). "
    error_detail += "Please ensure the backend encryption service is running and accessible, or that Supabase RPC 'decrypt_password' is available."
    
    raise HTTPException(status_code=500, detail=error_detail)


def _map_account(row: Dict[str, Any]) -> AccountResponse:
    return AccountResponse(**row)


def create_or_update_account(user_id: str, payload: AccountConnectRequest) -> AccountResponse:
    """
    Upsert account for the user. If account with same login/server exists,
    update metadata and password; otherwise insert new record.
    """
    client = _require_supabase()
    encrypted_password = encrypt_password(payload.password)

    data = {
        "user_id": user_id,
        "account_name": payload.account_name or f"{payload.login}@{payload.server}",
        "login": payload.login,
        "server": payload.server,
        "broker_name": payload.broker_name,
        "account_type": payload.account_type or "demo",
        "encrypted_password": encrypted_password,
        "password_encrypted": encrypted_password,
        "is_default": payload.set_as_default,
        "is_active": True,
    }
    if payload.risk_limits:
        data["risk_limits"] = payload.risk_limits

    try:
        (
            client.table(MT5_ACCOUNTS_TABLE)
            .upsert(data, on_conflict="user_id,login,server")
            .execute()
        )

        response = (
            client.table(MT5_ACCOUNTS_TABLE)
            .select("*")
            .eq("user_id", user_id)
            .eq("login", payload.login)
            .eq("server", payload.server)
            .single()
            .execute()
        )
        row = response.data
    except Exception as exc:
        logger.error("Failed to store MT5 account: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to store MT5 account")

    # Ensure only one default account per user
    if payload.set_as_default:
        try:
            (
                client.table(MT5_ACCOUNTS_TABLE)
                .update({"is_default": False})
                .eq("user_id", user_id)
                .neq("id", row["id"])
                .execute()
            )
        except Exception as exc:
            logger.warning("Failed to reset other default accounts: %s", exc)

    return _map_account(row)


def list_accounts(user_id: str):
    client = _require_supabase()
    try:
        response = (
            client.table(MT5_ACCOUNTS_TABLE)
            .select("*")
            .eq("user_id", user_id)
            .eq("is_active", True)
            .order("created_at", desc=False)
            .execute()
        )
        return [_map_account(row) for row in response.data or []]
    except Exception as exc:
        logger.error("Failed to list accounts: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to list accounts")


def get_account(user_id: str, account_id: str) -> AccountResponse:
    client = _require_supabase()
    try:
        response = (
            client.table(MT5_ACCOUNTS_TABLE)
            .select("*")
            .eq("user_id", user_id)
            .eq("id", account_id)
            .single()
            .execute()
        )
        if response.data is None:
            raise HTTPException(status_code=404, detail="Account not found")
        return _map_account(response.data)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to fetch account: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to fetch account")


def update_account(user_id: str, account_id: str, payload: AccountUpdateRequest) -> AccountResponse:
    client = _require_supabase()
    updates: Dict[str, Any] = {}
    if payload.account_name is not None:
        updates["account_name"] = payload.account_name
    if payload.broker_name is not None:
        updates["broker_name"] = payload.broker_name
    if payload.account_type is not None:
        updates["account_type"] = payload.account_type
    if payload.risk_limits is not None:
        updates["risk_limits"] = payload.risk_limits
    if payload.is_active is not None:
        updates["is_active"] = payload.is_active
    if payload.is_default is not None:
        updates["is_default"] = payload.is_default

    if not updates:
        return get_account(user_id, account_id)

    try:
        response = (
            client.table(MT5_ACCOUNTS_TABLE)
            .update(updates)
            .eq("user_id", user_id)
            .eq("id", account_id)
            .select("*")
            .single()
            .execute()
        )
        row = response.data
    except Exception as exc:
        logger.error("Failed to update account: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to update account")

    if payload.is_default:
        try:
            (
                client.table(MT5_ACCOUNTS_TABLE)
                .update({"is_default": False})
                .eq("user_id", user_id)
                .neq("id", account_id)
                .execute()
            )
        except Exception as exc:
            logger.warning("Failed to reset default flag on other accounts: %s", exc)

    return _map_account(row)


def delete_account(user_id: str, account_id: str):
    client = _require_supabase()
    try:
        (
            client.table(MT5_ACCOUNTS_TABLE)
            .update({"is_active": False, "is_default": False})
            .eq("user_id", user_id)
            .eq("id", account_id)
            .execute()
        )
    except Exception as exc:
        logger.error("Failed to delete account: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to delete account")


def get_default_account(user_id: str) -> Optional[AccountResponse]:
    client = _require_supabase()
    try:
        response = (
            client.table(MT5_ACCOUNTS_TABLE)
            .select("*")
            .eq("user_id", user_id)
            .eq("is_active", True)
            .eq("is_default", True)
            .single()
            .execute()
        )
        if not response.data:
            return None
        return _map_account(response.data)
    except Exception:
        return None

