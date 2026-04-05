
**FiveM VCR GTA**

**AWS インフラ システム設計書**



バージョン: 1.0

対象環境: dev（開発） / prd（本番）

作成日: 2025年



**FiveM VCR GTA  AWS インフラ システム設計書**    ver 1.0
# **1. システム概要**
本システムは、GTA5用マルチプレイヤーMODクライアント「FiveM（FXServer）」をAWS上で運用するためのインフラ基盤です。VCR GTAサーバーとして、ロールプレイプレイヤー向けの安定した専用環境を提供します。

## **1.1 主な特徴**
- IaC（Infrastructure as Code）: Terraform でインフラを、Ansible でサーバー設定を完全コード管理
- 2環境分離: 開発（dev）と本番（prd）を別リージョン・別スペックで独立管理
- ホワイトリスト方式: Discord Bot + FastAPI により、承認済みプレイヤーのみが入室可能
- DDoS 対策: AWS Shield / Global Accelerator / iptables の 3 層防御
- 近接ボイスチャット: 内蔵 Mumble により、ゲーム内位置に連動した音声通話を実現

## **1.2 構成コンポーネント一覧**

|**コンポーネント**|**技術スタック**|**役割**|
| :- | :- | :- |
|**IaC（インフラ管理）**|Terraform >= 1.6|VPC / EC2 / SG / IAM / Global Accelerator をコードで管理|
|**サーバー設定管理**|Ansible >= 2.15|OS・FXServer・MariaDB・APIの自動セットアップ|
|**ゲームサーバー**|FiveM FXServer|GTA5 マルチプレイヤー基盤。txAdmin で GUI 管理|
|**データベース**|MariaDB 10.11|ホワイトリスト・バン情報・プレイヤーデータを保管|
|**ホワイトリスト API**|Python / FastAPI|Steam ID の登録・削除・確認を HTTP API で提供|
|**Discord Bot**|discord.py|/register コマンドでプレイヤーが自己申請できる窓口|
|**CI/CD**|GitHub Actions|PR 時に Terraform Plan、main マージで自動デプロイ|


# **2. 環境定義**
開発環境（dev）と本番環境（prd）の 2 系統を完全分離しています。それぞれ異なるリージョン・インスタンス種別を採用しており、設定ファイルも独立しています。

|**項目**|**開発環境（dev）**|**本番環境（prd）**|
| :- | :- | :- |
|**AWSリージョン**|東京（ap-northeast-1）|バージニア北部（us-east-1）|
|**ホスト形態**|仮想共有インスタンス|Dedicated Hosts（物理専有）|
|**インスタンス型**|t3.medium|c5.metal または m5.metal|
|**vCPU**|2 コア|96 コア（c5.metal）|
|**メモリ**|4 GB|192 GB（c5.metal）|
|**最大接続人数**|5 名（テスト用）|128 名以上|
|**OS**|Ubuntu 24.04 LTS|Ubuntu 24.04 LTS|
|**ルートディスク**|gp3 30 GB|gp3 50 GB|
|**データディスク**|gp3 50 GB（/opt/fivem）|gp3 200 GB（/opt/fivem）|
|**ネットワーク**|Elastic IP（固定 IP）|Global Accelerator + Elastic IP|
|**DDoS 対策**|Shield Standard + iptables|Shield Standard + Global Accelerator + iptables|
|**データベース**|MariaDB（ローカル）|MariaDB（ローカル）→ RDS へ移行可|
|**Terraform State**|S3（ap-northeast-1）|S3（us-east-1）|

📌 Dedicated Host（物理専有）は AWS が物理サーバーを 1 台丸ごと専有するオプションです。他テナントと CPU を共有しないため、ゲームサーバーのレイテンシが安定します。


# **3. AWS アーキテクチャ**
## **3.1 dev 環境（東京リージョン）**

|**レイヤー**|**構成要素**|
| :- | :- |
|**ネットワーク**|VPC（10.0.0.0/16）/ パブリックサブネット（10.0.1.0/24）/ Internet Gateway / Elastic IP|
|**コンピュート**|EC2 t3.medium（Ubuntu 24.04）/ 共有インスタンス / IAM Instance Profile|
|**セキュリティ**|Security Group（SSH:22, FiveM:30120 TCP/UDP, txAdmin:40120, API:8000）|
|**監視**|CloudWatch CPU アラーム（85%閾値）|
|**状態管理**|Terraform State → S3（ap-northeast-1）/ DynamoDB ロックテーブル|

## **3.2 prd 環境（バージニア北部リージョン）**

|**レイヤー**|**構成要素**|
| :- | :- |
|**ネットワーク**|VPC（10.1.0.0/16）/ パブリックサブネット（10.1.1.0/24）/ Internet Gateway / Elastic IP|
|**コンピュート**|EC2 c5.metal（Ubuntu 24.04）/ Dedicated Host（物理専有）/ IAM Instance Profile|
|**グローバル配信**|AWS Global Accelerator（静的エニーキャスト IP × 2）/ エッジでのトラフィック受信|
|**セキュリティ**|Security Group（SSH:22, FiveM:30120 TCP/UDP, txAdmin:40120, API:8000）|
|**ログ**|S3 バケット（Global Accelerator フローログ / 90 日保持）|
|**監視・通知**|CloudWatch CPU アラーム（85%閾値）→ SNS → メール通知|
|**状態管理**|Terraform State → S3（us-east-1）/ DynamoDB ロックテーブル|

## **3.3 使用 AWS サービス一覧**

|**サービス名**|**dev**|**prd**|**用途・説明**|
| :- | :- | :- | :- |
|**Amazon EC2**|✅|✅|FiveM サーバー本体を稼働させる仮想／物理サーバー|
|**Amazon VPC**|✅|✅|プライベートネットワーク空間。サブネット・ルートテーブルを管理|
|**Elastic IP**|✅|✅|サーバーの固定グローバル IP。再起動しても IP が変わらない|
|**AWS Global Accelerator**|－|✅|世界中のエッジから最適ルートでサーバーへ誘導。DDoS 吸収にも効果的|
|**AWS Shield Standard**|✅|✅|DDoS 攻撃の基本防御（無料）。大規模攻撃は GA と組み合わせる|
|**Amazon S3**|✅|✅|Terraform State ファイルの保管。prd はフローログも格納|
|**Amazon DynamoDB**|✅|✅|Terraform の State ロック管理テーブル|
|**Amazon CloudWatch**|✅|✅|EC2 CPU 使用率を監視。閾値超過でアラームを発火|
|**Amazon SNS**|－|✅|CloudWatch アラームをメールへ転送する通知バス|
|**AWS IAM**|✅|✅|EC2 に SSM / CloudWatch の権限を付与する Role / Profile|
|**AWS SSM Session Manager**|✅|✅|SSH 不要で EC2 にブラウザ接続できるセキュアアクセス手段|
|**EC2 Dedicated Hosts**|－|✅|物理ホスト専有。c5.metal / m5.metal を配置するために必須|


# **4. ネットワーク・セキュリティ設計**
## **4.1 ポート開放ルール**

|**ポート**|**プロトコル**|**環境**|**アクセス元**|**用途**|
| :- | :- | :- | :- | :- |
|**22**|TCP|dev/prd|管理者 IP のみ|SSH ログイン（緊急時）|
|**30120**|TCP|dev/prd|0\.0.0.0/0（全体）|FiveM ゲーム接続ポート|
|**30120**|UDP|dev/prd|0\.0.0.0/0（全体）|FiveM UDP + Mumble ボイスチャット|
|**40120**|TCP|dev/prd|管理者 IP のみ|txAdmin 管理パネル（Web UI）|
|**8000**|TCP|dev/prd|dev: 全体 / prd: Bot サーバー IP|ホワイトリスト FastAPI|

## **4.2 DDoS 対策（3 層構造）**

|**層**|**技術**|**環境**|**効果**|
| :- | :- | :- | :- |
|**L1**|AWS Shield Standard|dev / prd|SYN Flood・UDP Flood などの標準的な L3/L4 攻撃を自動遮断（無料）|
|**L2**|Global Accelerator|prd のみ|AWS エッジで攻撃トラフィックを吸収。オリジン IP を隠蔽し直接攻撃を防ぐ|
|**L3**|iptables レートリミット|dev: 100/s / prd: 50/s|OS レベルで UDP 30120 への送信元 IP ごとのレートを制限し、UDP Flood を軽減|


# **5. アプリケーション構成**
## **5.1 FXServer（FiveM ゲームサーバー）**

|**インストール先**|/opt/fivem/server/|
| :- | :- |
|**設定ファイル**|/opt/fivem/server.cfg（Ansible Jinja2 テンプレートで生成）|
|**リソース格納**|/opt/fivem/resources/（GitHub から自動クローン）|
|**プロセス管理**|systemd（fivem.service）- 異常終了時に自動再起動|
|**管理 UI**|txAdmin（ポート 40120）- ブラウザから操作可|
|**ゲームビルド**|sv\_enforceGameBuild 3095（GTA5 ビルドを固定）|
|**OneSync**|有効（大人数同期。128 名以上の接続に必要）|
|**ボイスチャット**|内蔵 Mumble / ポート 30120 UDP / 近接距離 30.0 単位|

## **5.2 MariaDB データベース**

|**バージョン**|MariaDB 10.11|
| :- | :- |
|**データベース名**|fivem|
|**文字コード**|utf8mb4 / utf8mb4\_unicode\_ci|
|**接続方式**|localhost（dev/prd フェーズ 1,2）→ Amazon RDS へ移行可（フェーズ 3）|
|**テーブル**|whitelist（ホワイトリスト）/ bans（バン情報）+ MOD リソース用テーブル|

## **5.3 ホワイトリスト API（FastAPI）**
Python / FastAPI 製の軽量 REST API。プレイヤーの Steam ID を DB に登録・削除・確認します。

|**エンドポイント**|**メソッド**|**説明**|
| :- | :- | :- |
|/whitelist|**POST**|Steam ID をホワイトリストに新規登録。重複時は 409 を返す|
|/whitelist/{id}|**GET**|指定 Steam ID がホワイトリストに存在するか確認|
|/whitelist/{id}|**DELETE**|指定 Steam ID をホワイトリストから削除（管理者用）|
|/health|**GET**|API サーバーの死活確認。監視ツールから定期ポーリング|

📌 全エンドポイントは X-API-Token ヘッダーによる認証が必須です。prd 環境では接続元 IP も制限します。

## **5.4 Discord Bot**
discord.py 製のスラッシュコマンド Bot。プレイヤーが自分で Steam ID を登録できる窓口です。

|**コマンド**|**権限**|**動作**|
| :- | :- | :- |
|/register steam\_id:|全メンバー|Steam ID を入力するとホワイトリスト API へ POST し、自動で DB に登録|
|/unregister steam\_id:|管理者のみ|指定 Steam ID をホワイトリストから削除（BANなど）|


# **6. インフラ管理（Terraform / Ansible）**
## **6.1 Terraform ディレクトリ構成**

|**パス**|**内容**|
| :- | :- |
|terraform/modules/vpc/|VPC・サブネット・IGW・Elastic IP を定義する共通モジュール|
|terraform/modules/sg/|Security Group（ポート開放ルール）を定義する共通モジュール|
|terraform/modules/ec2/|EC2 インスタンス・EBS・Dedicated Host・CloudWatch を定義|
|terraform/modules/iam/|EC2 用 IAM Role / Instance Profile（SSM・CloudWatch 権限）|
|terraform/environments/dev/|東京リージョン dev 環境の main.tf / variables.tf / outputs.tf|
|terraform/environments/prd/|us-east-1 prd 環境（Dedicated Host・Global Accelerator・SNS 含む）|
|scripts/bootstrap-tfstate.sh|S3 バケットと DynamoDB テーブルを初回作成するシェルスクリプト|

## **6.2 Ansible ロール構成**

|**ロール名**|**処理内容**|
| :- | :- |
|**fivem**|FXServer のダウンロード・展開・server.cfg 生成・systemd 登録・iptables 設定|
|**mariadb**|MariaDB インストール・データベース作成・whitelist / bans テーブル初期化|
|**mods**|GitHub リポジトリから VCR GTA MOD をクローン・更新|
|**whitelist-api**|FastAPI アプリのデプロイ・venv 構築・systemd サービス登録|

## **6.3 設定変更フロー**
group\_vars/{dev,prd}.yml の変数を変更 → Ansible を再実行 → Handlers が FiveM を自動再起動

|**変更したい内容**|**変更ファイル**|**適用コマンド**|
| :- | :- | :- |
|最大接続人数を変更|group\_vars/prd.yml → fivem\_max\_clients|make prd-provision|
|MOD リポジトリを追加|group\_vars/dev.yml → mod\_repos|make dev-mods|
|DB パスワードを変更|group\_vars/vault.yml（暗号化）|make dev-provision|
|server.cfg の設定変更|ansible/templates/server.cfg.j2|make dev-provision|


# **7. 運用・拡張フェーズ**

|**フェーズ**|**環境**|**内容**|**完了条件**|
| :- | :- | :- | :- |
|**Phase 1**|dev（東京）|t3.medium で FiveM・MOD・ホワイトリスト API の動作確認。最大 5 名でテスト|全 MOD が起動し、Discord Bot 経由でホワイトリスト登録が動作すること|
|**Phase 2**|prd（us-east-1）|Dedicated Host を確保し c5.metal で本番環境を構築。Global Accelerator 経由で公開|128 名同時接続で安定動作すること|
|**Phase 3**|prd スケールアップ|fivem\_max\_clients を増加。DB 負荷に応じて MariaDB → Amazon RDS（Multi-AZ）へ移行|use\_rds: true に変更し Ansible で切り替え完了すること|

## **7.1 主要コマンド早見表（Makefile）**

|**コマンド**|**内容**|
| :- | :- |
|**make dev-init**|dev 環境の Terraform を初期化（初回のみ）|
|**make dev-apply**|dev の VPC / EC2 / SG 等を AWS に作成・更新|
|**make dev-provision**|dev サーバーに Ansible で FiveM・DB・API を全セットアップ|
|**make dev-mods**|dev の MOD リポジトリのみ最新化して FiveM を再起動|
|**make prd-apply**|prd の Dedicated Host / EC2 / Global Accelerator を作成・更新|
|**make prd-provision**|prd サーバーに Ansible で全セットアップ|
|**make prd-mods**|prd の MOD のみ更新|
|**make encrypt-vault**|ansible/group\_vars/vault.yml を暗号化（秘密情報保護）|


# **8. セキュリティ設計**
## **8.1 認証・アクセス管理**
- SSH アクセス: 管理者 IP のみ許可（本番は IP を絞ること）
- txAdmin: 管理者 IP のみ許可。初回起動時にパスワード設定が必要
- Whitelist API: X-API-Token ヘッダー認証 + prd は接続元 IP 制限
- AWS SSM Session Manager: SSH 不要でブラウザからサーバー操作可能（推奨）
- IAM 最小権限: EC2 に付与するのは SSM と CloudWatch のみ

## **8.2 秘密情報管理**
- Ansible Vault: ライセンスキー・DB パスワード・API トークンを暗号化
- vault.yml は ansible-vault encrypt で暗号化し Git 管理。平文では保存しない
- Terraform の秘密変数: terraform.tfvars は .gitignore で除外
- GitHub Secrets: CI/CD パイプラインの認証情報は GitHub Secrets に保管

## **8.3 OS セキュリティ**
- fail2ban: SSH ブルートフォース攻撃を自動ブロック
- iptables: UDP 30120 のレートリミットで UDP Flood を軽減
- NoNewPrivileges / PrivateTmp: systemd サービスのサンドボックス設定
- ディスク暗号化: EBS ボリューム（gp3）は全て暗号化有効


# **9. 用語集**

|**用語**|**説明**|
| :- | :- |
|**FiveM / FXServer**|GTA5 のマルチプレイヤー MOD フレームワーク。公式サーバーとは別に独自サーバーを立てられる|
|**txAdmin**|FiveM サーバーをブラウザから管理できる GUI パネル。プレイヤー管理・リソース管理が可能|
|**Terraform**|AWS などのインフラをコード（HCL 形式）で定義・管理するツール。IaC の代表格|
|**Ansible**|SSH 経由でサーバーの設定・ソフトウェアインストールを自動化するツール|
|**Dedicated Host**|AWS の物理サーバーを 1 台専有するオプション。他ユーザーと CPU を共有しない|
|**Global Accelerator**|AWS のエッジロケーションを利用して通信を最適化するサービス。世界中から低遅延でアクセス可能|
|**Elastic IP**|AWS が提供する固定グローバル IP アドレス。インスタンスを再起動しても変わらない|
|**OneSync**|FiveM の大人数同期機能。これを有効にすることで 64 名超の同時接続が可能になる|
|**Steam ID**|Steam プラットフォームが各アカウントに付与する一意 ID。FiveM の認証に使用|
|**Ansible Vault**|Ansible の秘密情報暗号化機能。パスワードや API キーをファイルに暗号化して保管できる|
|**IaC**|Infrastructure as Code の略。インフラの構成をコードで管理し、再現性と変更履歴を確保する手法|
|**gp3**|AWS EBS（仮想ディスク）の種類。SSD ベースで費用対効果が高い汎用ボリューム|

Confidential  -  Internal Use Only	 / 
