# Makefile - FiveM VCR GTA Infrastructure
# 使用例: make dev-apply / make prd-plan / make dev-provision

ANSIBLE_DIR   := ansible
TERRAFORM_DIR := terraform
VAULT_PASS    := $(ANSIBLE_DIR)/.vault_pass

.PHONY: help \
        dev-init dev-plan dev-apply dev-destroy \
        prd-init prd-plan prd-apply \
        dev-provision prd-provision \
        dev-mods prd-mods \
        encrypt-vault

help:
	@echo ""
	@echo "===== FiveM VCR GTA - コマンド一覧 ====="
	@echo ""
	@echo "【Terraform】"
	@echo "  make dev-init      - dev Terraform 初期化"
	@echo "  make dev-plan      - dev 変更プレビュー"
	@echo "  make dev-apply     - dev インフラ構築/更新"
	@echo "  make dev-destroy   - dev インフラ削除"
	@echo "  make prd-init      - prd Terraform 初期化"
	@echo "  make prd-plan      - prd 変更プレビュー"
	@echo "  make prd-apply     - prd インフラ構築/更新"
	@echo ""
	@echo "【Ansible】"
	@echo "  make dev-provision - dev サーバー全構成"
	@echo "  make prd-provision - prd サーバー全構成"
	@echo "  make dev-mods      - dev MODのみ更新"
	@echo "  make prd-mods      - prd MODのみ更新"
	@echo ""
	@echo "【その他】"
	@echo "  make encrypt-vault - vault.yml を暗号化"
	@echo ""

# -----------------------------------------------
# Terraform - dev
# -----------------------------------------------
dev-init:
	cd $(TERRAFORM_DIR)/environments/dev && terraform init

dev-plan:
	cd $(TERRAFORM_DIR)/environments/dev && terraform plan -var-file=terraform.tfvars

dev-apply:
	cd $(TERRAFORM_DIR)/environments/dev && terraform apply -var-file=terraform.tfvars -auto-approve

dev-destroy:
	cd $(TERRAFORM_DIR)/environments/dev && terraform destroy -var-file=terraform.tfvars

# -----------------------------------------------
# Terraform - prd
# -----------------------------------------------
prd-init:
	cd $(TERRAFORM_DIR)/environments/prd && terraform init

prd-plan:
	cd $(TERRAFORM_DIR)/environments/prd && terraform plan -var-file=terraform.tfvars

prd-apply:
	cd $(TERRAFORM_DIR)/environments/prd && terraform apply -var-file=terraform.tfvars -auto-approve

# -----------------------------------------------
# Ansible
# -----------------------------------------------
dev-provision:
	cd $(ANSIBLE_DIR) && \
	ansible-playbook -i inventory/hosts.yml site.yml \
	  --limit dev \
	  --vault-password-file $(VAULT_PASS)

prd-provision:
	cd $(ANSIBLE_DIR) && \
	ansible-playbook -i inventory/hosts.yml site.yml \
	  --limit prd \
	  --vault-password-file $(VAULT_PASS)

dev-mods:
	cd $(ANSIBLE_DIR) && \
	ansible-playbook -i inventory/hosts.yml site.yml \
	  --limit dev --tags mods \
	  --vault-password-file $(VAULT_PASS)

prd-mods:
	cd $(ANSIBLE_DIR) && \
	ansible-playbook -i inventory/hosts.yml site.yml \
	  --limit prd --tags mods \
	  --vault-password-file $(VAULT_PASS)

# -----------------------------------------------
# Vault
# -----------------------------------------------
encrypt-vault:
	cd $(ANSIBLE_DIR) && \
	ansible-vault encrypt group_vars/vault.yml \
	  --vault-password-file $(VAULT_PASS)
