#!/usr/bin/env python3
"""
whitelist-api/test_api.py
ホワイトリスト API の動作確認スクリプト
使い方: python test_api.py --host http://localhost:8000 --token YOUR_TOKEN
"""
import argparse
import sys
import requests

def run_tests(host: str, token: str):
    headers = {"X-API-Token": token}
    test_steam_id = "steam:110000112345678"
    passed = 0
    failed = 0

    def check(label, resp, expected_status):
        nonlocal passed, failed
        ok = resp.status_code == expected_status
        status = "✅ PASS" if ok else f"❌ FAIL (got {resp.status_code})"
        print(f"  {status}  {label}")
        if not ok:
            print(f"         Response: {resp.text}")
            failed += 1
        else:
            passed += 1

    print(f"\n=== Whitelist API Tests: {host} ===\n")

    # ヘルスチェック
    r = requests.get(f"{host}/health")
    check("GET /health → 200", r, 200)

    # 登録
    r = requests.post(f"{host}/whitelist", headers=headers, json={
        "steam_id": test_steam_id,
        "cfx_id": "testplayer",
        "discord_id": "123456789",
        "note": "テストユーザー"
    })
    check("POST /whitelist → 200 (新規登録)", r, 200)

    # 重複登録
    r = requests.post(f"{host}/whitelist", headers=headers, json={"steam_id": test_steam_id})
    check("POST /whitelist → 409 (重複)", r, 409)

    # 確認
    r = requests.get(f"{host}/whitelist/{test_steam_id}", headers=headers)
    check("GET /whitelist/:id → 200 (存在確認)", r, 200)

    # 削除
    r = requests.delete(f"{host}/whitelist/{test_steam_id}", headers=headers)
    check("DELETE /whitelist/:id → 200 (削除)", r, 200)

    # 削除後の確認
    r = requests.get(f"{host}/whitelist/{test_steam_id}", headers=headers)
    check("GET /whitelist/:id → 404 (削除後)", r, 404)

    # 認証エラー
    r = requests.get(f"{host}/whitelist/{test_steam_id}", headers={"X-API-Token": "wrong"})
    check("GET /whitelist/:id → 403 (不正トークン)", r, 403)

    print(f"\n結果: {passed} passed / {failed} failed\n")
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="http://localhost:8000")
    parser.add_argument("--token", required=True)
    args = parser.parse_args()
    run_tests(args.host, args.token)
