terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "fivem-terraform-state-dev"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "fivem-terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}

# -----------------------------------------------
# IAM
# -----------------------------------------------
module "iam" {
  source  = "../../modules/iam"
  project = var.project
  env     = "dev"
}

# -----------------------------------------------
# VPC
# -----------------------------------------------
module "vpc" {
  source             = "../../modules/vpc"
  project            = var.project
  env                = "dev"
  vpc_cidr           = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
  availability_zone  = "${var.aws_region}a"
}

# -----------------------------------------------
# Security Group
# -----------------------------------------------
module "sg" {
  source            = "../../modules/sg"
  project           = var.project
  env               = "dev"
  vpc_id            = module.vpc.vpc_id
  admin_cidr_blocks = var.admin_cidr_blocks
  api_cidr_blocks   = ["0.0.0.0/0"]
}

# -----------------------------------------------
# EC2 (t3.medium / 共有インスタンス)
# -----------------------------------------------
module "ec2" {
  source              = "../../modules/ec2"
  project             = var.project
  env                 = "dev"
  ami_id              = var.ami_id
  instance_type       = "t3.medium"
  subnet_id           = module.vpc.public_subnet_id
  security_group_id   = module.sg.fivem_sg_id
  key_name            = var.key_name
  eip_allocation_id   = module.vpc.eip_id
  availability_zone   = "${var.aws_region}a"
  use_dedicated_host  = false
  root_volume_size    = 30
  data_volume_size    = 50
}
