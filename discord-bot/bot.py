"""
discord-bot/bot.py
Discord から FiveM ホワイトリストに登録するボット
使い方:
  /register steam_id:steam:110000112345678
"""
import os
import re
import logging

import aiohttp
import discord
from discord import app_commands
from dotenv import load_dotenv

load_dotenv()

DISCORD_TOKEN     = os.getenv("DISCORD_TOKEN", "")
WHITELIST_API_URL = os.getenv("WHITELIST_API_URL", "http://localhost:8000")
WHITELIST_TOKEN   = os.getenv("WHITELIST_API_TOKEN", "")
ALLOWED_CHANNEL_ID = int(os.getenv("ALLOWED_CHANNEL_ID", "0"))   # 0 = 全チャンネル許可

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("whitelist-bot")

STEAM_ID_RE = re.compile(r"^steam:[0-9a-fA-F]{1,17}$")

# -----------------------------------------------
# Discord Client
# -----------------------------------------------
intents = discord.Intents.default()
client = discord.Client(intents=intents)
tree = app_commands.CommandTree(client)


@client.event
async def on_ready():
    await tree.sync()
    log.info(f"Bot ready: {client.user}")


# -----------------------------------------------
# /register コマンド
# -----------------------------------------------
@tree.command(name="register", description="FiveM ホワイトリストに Steam ID を登録します")
@app_commands.describe(steam_id="Steam ID (例: steam:110000112345678)")
async def register(interaction: discord.Interaction, steam_id: str):
    # チャンネル制限
    if ALLOWED_CHANNEL_ID and interaction.channel_id != ALLOWED_CHANNEL_ID:
        await interaction.response.send_message(
            "❌ このチャンネルでは登録できません。", ephemeral=True
        )
        return

    steam_id = steam_id.strip().lower()

    if not STEAM_ID_RE.match(steam_id):
        await interaction.response.send_message(
            "❌ Steam ID の形式が正しくありません。\n"
            "例: `steam:110000112345678`",
            ephemeral=True
        )
        return

    await interaction.response.defer(ephemeral=True)

    payload = {
        "steam_id": steam_id,
        "discord_id": str(interaction.user.id),
        "note": f"Discord: {interaction.user.display_name}"
    }

    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{WHITELIST_API_URL}/whitelist",
                json=payload,
                headers={"X-API-Token": WHITELIST_TOKEN},
                timeout=aiohttp.ClientTimeout(total=10)
            ) as resp:
                if resp.status == 200:
                    await interaction.followup.send(
                        f"✅ **ホワイトリスト登録完了！**\n"
                        f"Steam ID: `{steam_id}`\n"
                        f"サーバーに接続できるようになりました。",
                        ephemeral=True
                    )
                    log.info(f"Registered: {steam_id} by {interaction.user}")
                elif resp.status == 409:
                    await interaction.followup.send(
                        f"⚠️ `{steam_id}` はすでに登録されています。",
                        ephemeral=True
                    )
                else:
                    body = await resp.text()
                    log.error(f"API error {resp.status}: {body}")
                    await interaction.followup.send(
                        "❌ 登録に失敗しました。管理者に連絡してください。",
                        ephemeral=True
                    )
    except aiohttp.ClientError as e:
        log.error(f"API connection error: {e}")
        await interaction.followup.send(
            "❌ サーバーに接続できませんでした。しばらく待ってから再試行してください。",
            ephemeral=True
        )


# -----------------------------------------------
# /unregister コマンド (管理者専用)
# -----------------------------------------------
@tree.command(name="unregister", description="[管理者] ホワイトリストから Steam ID を削除します")
@app_commands.describe(steam_id="削除する Steam ID")
@app_commands.default_permissions(administrator=True)
async def unregister(interaction: discord.Interaction, steam_id: str):
    await interaction.response.defer(ephemeral=True)
    steam_id = steam_id.strip().lower()

    try:
        async with aiohttp.ClientSession() as session:
            async with session.delete(
                f"{WHITELIST_API_URL}/whitelist/{steam_id}",
                headers={"X-API-Token": WHITELIST_TOKEN},
                timeout=aiohttp.ClientTimeout(total=10)
            ) as resp:
                if resp.status == 200:
                    await interaction.followup.send(
                        f"✅ `{steam_id}` をホワイトリストから削除しました。",
                        ephemeral=True
                    )
                elif resp.status == 404:
                    await interaction.followup.send(
                        f"⚠️ `{steam_id}` はホワイトリストに存在しません。",
                        ephemeral=True
                    )
                else:
                    await interaction.followup.send("❌ 削除に失敗しました。", ephemeral=True)
    except aiohttp.ClientError as e:
        log.error(f"API error: {e}")
        await interaction.followup.send("❌ API 接続エラー。", ephemeral=True)


client.run(DISCORD_TOKEN)
