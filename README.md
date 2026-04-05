# GTA5 FiveM - AWS Infrastructure

GTA5 FiveM (FXServer) サーバーを AWS 上に構築するための IaC リポジトリ。  
Terraform でインフラを、Ansible でサーバー設定を管理する。

---
# システム設計書
[fivem-aws-system-design.md](fivem-aws-system-design.md)

---

## ディレクトリ構成

```
.
├── Makefile                      # 運用コマンド集
├── terraform/
│   ├── modules/                  # 共通モジュール (vpc / sg / ec2 / iam)
│   └── environments/
│       ├── dev/                  # 東京リージョン / t3.medium
│       └── prd/                  # us-east-1 / c5.metal (Dedicated Host)
├── ansible/
│   ├── site.yml                  # フルセットアップ Playbook
│   ├── update-config.yml         # 設定変更のみ軽量 Playbook
│   ├── group_vars/
│   │   ├── dev.yml               # dev 変数 (max_clients, MOD リポジトリ 等)
│   │   ├── prd.yml               # prd 変数
│   │   └── vault.yml             # 秘密情報 (ansible-vault で暗号化)
│   ├── templates/
│   │   ├── server.cfg.j2         # FiveM 設定テンプレート
│   │   └── fivem.service.j2      # systemd ユニットテンプレート
│   └── roles/
│       ├── fivem/                # FXServer インストール・iptables
│       ├── mariadb/              # DB 構築・スキーマ初期化
│       ├── mods/                 # MOD GitHub クローン
│       └── whitelist-api/        # FastAPI デプロイ
├── whitelist-api/
│   ├── main.py                   # FastAPI アプリ
│   ├── requirements.txt
│   └── test_api.py               # 動作確認スクリプト
└── discord-bot/
    ├── bot.py                    # /register / /unregister コマンド
    └── requirements.txt
```

---

## クイックスタート

### 前提条件

- Terraform >= 1.6
- Ansible >= 2.15
- AWS CLI 設定済み (`aws configure`)
- Python 3.12+

### Step 1: Terraform ステートバックエンド作成 (初回のみ)

```bash
bash scripts/bootstrap-tfstate.sh dev
bash scripts/bootstrap-tfstate.sh prd
```

### Step 2: tfvars 作成

```bash
cp terraform/environments/dev/terraform.tfvars.example \
   terraform/environments/dev/terraform.tfvars
# エディタで実際の値を記入
```

### Step 3: Vault パスワード設定

```bash
echo "your-strong-vault-password" > ansible/.vault_pass
chmod 600 ansible/.vault_pass
# vault.yml に秘密情報を記入してから暗号化
make encrypt-vault
```

### Step 4: dev 環境を構築

```bash
make dev-init     # Terraform 初期化
make dev-apply    # EC2 / VPC / SG 作成

# 出力された EIP を環境変数にセット
export DEV_SERVER_IP=$(cd terraform/environments/dev && terraform output -raw server_public_ip)

make dev-provision  # Ansible でサーバー設定
```

### Step 5: 動作確認

```bash
# txAdmin
open http://$DEV_SERVER_IP:40120

# Whitelist API テスト
python whitelist-api/test_api.py \
  --host http://$DEV_SERVER_IP:8000 \
  --token YOUR_WHITELIST_API_TOKEN
```

---

## 設定変更フロー

### max_clients / MOD リポジトリ を変更したい場合

```bash
# 1. group_vars/dev.yml (または prd.yml) を編集
#    例: fivem_max_clients: 32

# 2. 設定更新のみ適用 (軽量)
ansible-playbook -i ansible/inventory/hosts.yml ansible/update-config.yml \
  --limit dev --vault-password-file ansible/.vault_pass
```

### MOD のみ更新

```bash
make dev-mods   # dev
make prd-mods   # prd
```

---

## フェーズ移行

| Phase | 作業 | コマンド |
|-------|------|---------|
| 1 (dev) | 東京で動作確認 | `make dev-apply && make dev-provision` |
| 2 (prd) | us-east-1 に Dedicated Host で本番構築 | `make prd-apply && make prd-provision` |
| 3 (Scale) | `prd.yml` の `fivem_max_clients` 増加 + RDS 切替 | `make prd-mods` + `use_rds: true` |

---

## GitHub Actions Secrets 設定

| Secret 名 | 内容 |
|-----------|------|
| `AWS_ROLE_ARN_DEV` | dev デプロイ用 IAM Role ARN |
| `AWS_ROLE_ARN_PRD` | prd デプロイ用 IAM Role ARN |
| `TFVARS_DEV` | dev terraform.tfvars の内容 |
| `TFVARS_PRD` | prd terraform.tfvars の内容 |
| `SSH_PRIVATE_KEY_DEV` | dev サーバーの SSH 秘密鍵 |
| `SSH_PRIVATE_KEY_PRD` | prd サーバーの SSH 秘密鍵 |
| `VAULT_PASSWORD` | ansible-vault パスワード |

---

## ポート一覧

| ポート | プロトコル | 用途 |
|--------|-----------|------|
| 22 | TCP | SSH (admin IP のみ) |
| 30120 | TCP/UDP | FiveM ゲームポート + Mumble Voice |
| 40120 | TCP | txAdmin 管理パネル (admin IP のみ) |
| 8000 | TCP | Whitelist API |
