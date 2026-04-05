#!/bin/bash
set -euo pipefail

# タイムゾーン設定
timedatectl set-timezone Asia/Tokyo

# 基本パッケージ
apt-get update -y
apt-get install -y \
  python3 \
  python3-pip \
  git \
  curl \
  wget \
  unzip \
  xz-utils \
  mariadb-client \
  iptables-persistent

# FiveM データディレクトリ用マウント
DEVICE="/dev/nvme1n1"
MOUNT_POINT="/opt/fivem"
if ! blkid "$DEVICE" | grep -q ext4; then
  mkfs.ext4 "$DEVICE"
fi
mkdir -p "$MOUNT_POINT"
echo "$DEVICE $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
mount -a

# Ansible ユーザー作成 (プロビジョニング用)
useradd -m -s /bin/bash ansible || true
echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible

# 環境タグを保存
echo "ENV=${env}" > /etc/fivem-env
