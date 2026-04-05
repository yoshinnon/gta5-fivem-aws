#!/bin/bash
# scripts/bootstrap-tfstate.sh
# Terraform リモートステート用 S3 バケット & DynamoDB テーブルを作成する
# 初回のみ実行すること
set -euo pipefail

ENV="${1:-dev}"
REGION_DEV="ap-northeast-1"
REGION_PRD="us-east-1"

if [ "$ENV" = "dev" ]; then
  REGION="$REGION_DEV"
  BUCKET="fivem-terraform-state-dev"
else
  REGION="$REGION_PRD"
  BUCKET="fivem-terraform-state-prd"
fi

DYNAMO_TABLE="fivem-terraform-lock"

echo "=== Terraform State Bootstrap: $ENV ($REGION) ==="

# S3 バケット作成
if aws s3api head-bucket --bucket "$BUCKET" --region "$REGION" 2>/dev/null; then
  echo "[SKIP] S3 bucket $BUCKET already exists"
else
  aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGION" \
    $( [ "$REGION" != "us-east-1" ] && echo "--create-bucket-configuration LocationConstraint=$REGION" )

  aws s3api put-bucket-versioning \
    --bucket "$BUCKET" \
    --versioning-configuration Status=Enabled \
    --region "$REGION"

  aws s3api put-bucket-encryption \
    --bucket "$BUCKET" \
    --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
    --region "$REGION"

  aws s3api put-public-access-block \
    --bucket "$BUCKET" \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region "$REGION"

  echo "[OK] S3 bucket $BUCKET created"
fi

# DynamoDB テーブル (ロック用) - リージョンごとに作成
if aws dynamodb describe-table --table-name "$DYNAMO_TABLE" --region "$REGION" 2>/dev/null; then
  echo "[SKIP] DynamoDB table $DYNAMO_TABLE already exists"
else
  aws dynamodb create-table \
    --table-name "$DYNAMO_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION"
  echo "[OK] DynamoDB table $DYNAMO_TABLE created"
fi

echo ""
echo "=== Complete! Now run: make ${ENV}-init ==="
