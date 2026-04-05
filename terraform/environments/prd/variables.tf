variable "project" {
  type    = string
  default = "fivem-vcrgta"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type        = string
  description = "c5.metal or m5.metal"
  default     = "c5.metal"
}

variable "ami_id" {
  type        = string
  description = "Ubuntu 24.04 LTS AMI ID (us-east-1)"
  default     = "ami-0e86e20dae9224db8"
}

variable "key_name" {
  type        = string
  description = "EC2 Key Pair name"
}

variable "admin_cidr_blocks" {
  type        = list(string)
  description = "CIDRs allowed for SSH and txAdmin (本番では絞ること)"
}

variable "api_cidr_blocks" {
  type        = list(string)
  description = "CIDRs allowed for Whitelist API"
  default     = ["0.0.0.0/0"]
}

variable "alert_email" {
  type        = string
  description = "Email address for CloudWatch alerts"
}
