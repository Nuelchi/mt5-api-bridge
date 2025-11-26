from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field, validator


class AccountBase(BaseModel):
    account_name: Optional[str] = Field(None, max_length=255)
    broker_name: Optional[str] = Field(None, max_length=100)
    account_type: Optional[str] = Field(
        None, pattern="^(demo|live)$", description="demo or live"
    )
    risk_limits: Optional[dict] = None


class AccountConnectRequest(AccountBase):
    login: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=3)
    server: str = Field(..., min_length=3, max_length=255)
    set_as_default: bool = True

    @validator("login")
    def login_digits(cls, value: str) -> str:
        # MT5 account numbers are usually digits but allow brokers with chars
        return value.strip()


class AccountUpdateRequest(AccountBase):
    is_default: Optional[bool] = None
    is_active: Optional[bool] = None


class AccountResponse(BaseModel):
    id: str
    user_id: str
    account_name: Optional[str]
    login: str
    server: str
    broker_name: Optional[str]
    account_type: Optional[str]
    is_active: bool
    is_default: bool
    encrypted_password: Optional[str] = None
    balance: Optional[float] = None
    equity: Optional[float] = None
    risk_limits: Optional[dict] = None
    created_at: datetime
    updated_at: datetime


class AccountListResponse(BaseModel):
    accounts: List[AccountResponse]


class SwitchAccountResponse(BaseModel):
    success: bool
    account: AccountResponse

