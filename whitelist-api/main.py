"""
whitelist-api/main.py
FiveM ホワイトリスト自動登録 API (FastAPI)
"""
from __future__ import annotations

import os
import re
from typing import Optional

import aiomysql
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, Security
from fastapi.security.api_key import APIKeyHeader
from pydantic import BaseModel, field_validator

load_dotenv()

# -----------------------------------------------
# 設定
# -----------------------------------------------
DB_HOST     = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT     = int(os.getenv("DB_PORT", 3306))
DB_NAME     = os.getenv("DB_NAME", "fivem")
DB_USER     = os.getenv("DB_USER", "fivem")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
API_TOKEN   = os.getenv("API_TOKEN", "")
ALLOWED_IPS = [ip.strip() for ip in os.getenv("ALLOWED_IPS", "").split(",") if ip.strip()]

# -----------------------------------------------
# FastAPI
# -----------------------------------------------
app = FastAPI(
    title="FiveM Whitelist API",
    description="VCR GTA ホワイトリスト自動登録エンドポイント",
    version="1.0.0",
    docs_url="/docs" if os.getenv("ENV") == "dev" else None,
)

api_key_header = APIKeyHeader(name="X-API-Token", auto_error=True)


# -----------------------------------------------
# DB コネクションプール
# -----------------------------------------------
@app.on_event("startup")
async def startup():
    app.state.pool = await aiomysql.create_pool(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        db=DB_NAME,
        minsize=2,
        maxsize=10,
        autocommit=True,
    )


@app.on_event("shutdown")
async def shutdown():
    app.state.pool.close()
    await app.state.pool.wait_closed()


# -----------------------------------------------
# 認証・IP フィルター
# -----------------------------------------------
async def verify_token(api_key: str = Security(api_key_header)):
    if api_key != API_TOKEN:
        raise HTTPException(status_code=403, detail="Invalid API token")
    return api_key


def check_ip(request: Request):
    if not ALLOWED_IPS:
        return  # 空リスト = 全許可 (dev 環境)
    client_ip = request.client.host
    if client_ip not in ALLOWED_IPS:
        raise HTTPException(status_code=403, detail=f"IP {client_ip} is not allowed")


# -----------------------------------------------
# スキーマ
# -----------------------------------------------
STEAM_ID_RE = re.compile(r"^steam:[0-9a-fA-F]{1,17}$")
CFX_ID_RE   = re.compile(r"^[a-zA-Z0-9_\-]{3,64}$")


class WhitelistRequest(BaseModel):
    steam_id:   str
    cfx_id:     Optional[str] = None
    discord_id: Optional[str] = None
    note:       Optional[str] = None

    @field_validator("steam_id")
    @classmethod
    def validate_steam_id(cls, v: str) -> str:
        if not STEAM_ID_RE.match(v):
            raise ValueError("Invalid steam_id format. Expected: steam:HEXID")
        return v.lower()

    @field_validator("cfx_id")
    @classmethod
    def validate_cfx_id(cls, v: Optional[str]) -> Optional[str]:
        if v and not CFX_ID_RE.match(v):
            raise ValueError("Invalid cfx_id format")
        return v


class WhitelistResponse(BaseModel):
    success: bool
    message: str
    steam_id: str


# -----------------------------------------------
# エンドポイント
# -----------------------------------------------
@app.post("/whitelist", response_model=WhitelistResponse)
async def add_to_whitelist(
    payload: WhitelistRequest,
    request: Request,
    _token: str = Security(verify_token),
):
    """ホワイトリストに追加 (重複は 409)"""
    check_ip(request)

    async with app.state.pool.acquire() as conn:
        async with conn.cursor() as cur:
            # 重複チェック
            await cur.execute(
                "SELECT id FROM whitelist WHERE steam_id = %s", (payload.steam_id,)
            )
            if await cur.fetchone():
                raise HTTPException(
                    status_code=409,
                    detail=f"{payload.steam_id} is already whitelisted",
                )

            await cur.execute(
                """
                INSERT INTO whitelist (steam_id, cfx_id, discord_id, note, added_by)
                VALUES (%s, %s, %s, %s, 'api')
                """,
                (payload.steam_id, payload.cfx_id, payload.discord_id, payload.note),
            )

    return WhitelistResponse(
        success=True,
        message="Successfully added to whitelist",
        steam_id=payload.steam_id,
    )


@app.delete("/whitelist/{steam_id}", response_model=WhitelistResponse)
async def remove_from_whitelist(
    steam_id: str,
    request: Request,
    _token: str = Security(verify_token),
):
    """ホワイトリストから削除"""
    check_ip(request)
    steam_id = steam_id.lower()

    async with app.state.pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                "DELETE FROM whitelist WHERE steam_id = %s", (steam_id,)
            )
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail=f"{steam_id} not found")

    return WhitelistResponse(
        success=True,
        message="Successfully removed from whitelist",
        steam_id=steam_id,
    )


@app.get("/whitelist/{steam_id}")
async def check_whitelist(
    steam_id: str,
    request: Request,
    _token: str = Security(verify_token),
):
    """ホワイトリスト確認"""
    check_ip(request)

    async with app.state.pool.acquire() as conn:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT * FROM whitelist WHERE steam_id = %s", (steam_id.lower(),)
            )
            row = await cur.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail=f"{steam_id} not in whitelist")
    return row


@app.get("/health")
async def health():
    return {"status": "ok"}
