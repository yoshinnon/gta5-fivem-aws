terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "fivem-terraform-state-prd"
    key            = "prd/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "fivem-terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project
      Environment = "prd"
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
  env     = "prd"
}

# -----------------------------------------------
# VPC
# -----------------------------------------------
module "vpc" {
  source             = "../../modules/vpc"
  project            = var.project
  env                = "prd"
  vpc_cidr           = "10.1.0.0/16"
  public_subnet_cidr = "10.1.1.0/24"
  availability_zone  = "${var.aws_region}a"
}

# -----------------------------------------------
# Security Group
# -----------------------------------------------
module "sg" {
  source            = "../../modules/sg"
  project           = var.project
  env               = "prd"
  vpc_id            = module.vpc.vpc_id
  admin_cidr_blocks = var.admin_cidr_blocks
  api_cidr_blocks   = var.api_cidr_blocks
}

# -----------------------------------------------
# EC2 (c5.metal / Dedicated Host)
# -----------------------------------------------
module "ec2" {
  source             = "../../modules/ec2"
  project            = var.project
  env                = "prd"
  ami_id             = var.ami_id
  instance_type      = var.instance_type
  subnet_id          = module.vpc.public_subnet_id
  security_group_id  = module.sg.fivem_sg_id
  key_name           = var.key_name
  eip_allocation_id  = module.vpc.eip_id
  availability_zone  = "${var.aws_region}a"
  use_dedicated_host = true
  root_volume_size   = 50
  data_volume_size   = 200
  alarm_sns_arns     = [aws_sns_topic.alerts.arn]
}

# -----------------------------------------------
# Global Accelerator
# -----------------------------------------------
resource "aws_globalaccelerator_accelerator" "fivem" {
  name            = "${var.project}-prd-ga"
  ip_address_type = "IPV4"
  enabled         = true

  attributes {
    flow_logs_enabled   = true
    flow_logs_s3_bucket = aws_s3_bucket.logs.bucket
    flow_logs_s3_prefix = "global-accelerator/"
  }
}

resource "aws_globalaccelerator_listener" "fivem_tcp" {
  accelerator_arn = aws_globalaccelerator_accelerator.fivem.id
  client_affinity = "SOURCE_IP"
  protocol        = "TCP"

  port_range {
    from_port = 30120
    to_port   = 30120
  }
}

resource "aws_globalaccelerator_listener" "fivem_udp" {
  accelerator_arn = aws_globalaccelerator_accelerator.fivem.id
  client_affinity = "SOURCE_IP"
  protocol        = "UDP"

  port_range {
    from_port = 30120
    to_port   = 30120
  }
}

resource "aws_globalaccelerator_endpoint_group" "fivem" {
  listener_arn = aws_globalaccelerator_listener.fivem_tcp.id

  endpoint_configuration {
    endpoint_id                    = module.ec2.instance_id
    weight                         = 100
    client_ip_preservation_enabled = true
  }
}

# -----------------------------------------------
# S3 (ログ保管)
# -----------------------------------------------
resource "aws_s3_bucket" "logs" {
  bucket        = "${var.project}-prd-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = false
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    expiration { days = 90 }
    filter { prefix = "" }
  }
}

# -----------------------------------------------
# SNS (アラート通知)
# -----------------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "${var.project}-prd-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

data "aws_caller_identity" "current" {}
