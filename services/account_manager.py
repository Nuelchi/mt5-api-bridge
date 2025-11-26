"""
Supabase-backed MT5 account storage utilities.

Passwords are encrypted/decrypted via Supabase RPC functions that already
exist in the backend (handled outside this service). This module simply
invokes those RPCs and never implements crypto locally.
"""

import logging
from typing import Any, Dict, Optional

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
        response = client.rpc(function, payload).execute()
        return response.data
    except Exception as exc:
        logger.warning("RPC %s failed: %s", function, exc)
        return None


def encrypt_password(password: str) -> str:
    if not password:
        return password
    encrypted = _run_rpc(ENCRYPT_RPC, {"password": password})
    return encrypted or password


def decrypt_password(encrypted: str) -> str:
    if not encrypted:
        return encrypted
    decrypted = _run_rpc(DECRYPT_RPC, {"encrypted": encrypted})
    return decrypted or encrypted


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
        "is_default": payload.set_as_default,
        "is_active": True,
    }
    if payload.risk_limits:
        data["risk_limits"] = payload.risk_limits

    try:
        response = (
            client.table(MT5_ACCOUNTS_TABLE)
            .upsert(data, on_conflict="user_id,login,server")
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

