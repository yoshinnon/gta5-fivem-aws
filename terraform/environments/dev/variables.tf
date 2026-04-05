variable "project" {
  type    = string
  default = "fivem-vcrgta"
}

variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "ami_id" {
  type        = string
  description = "Ubuntu 24.04 LTS AMI ID (ap-northeast-1)"
  # 最新 Ubuntu 24.04 LTS: https://cloud-images.ubuntu.com/locator/ec2/
  default = "ami-0d52744d6551d851e"
}

variable "key_name" {
  type        = string
  description = "EC2 Key Pair name"
}

variable "admin_cidr_blocks" {
  type        = list(string)
  description = "CIDRs allowed for SSH and txAdmin (開発では全許可も可)"
  default     = ["0.0.0.0/0"]
}
