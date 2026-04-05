variable "project" { type = string }
variable "env" { type = string }
variable "vpc_id" { type = string }
variable "admin_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed for SSH and txAdmin"
  default     = ["0.0.0.0/0"] # 本番では絞ること
}
variable "api_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed for Whitelist API"
  default     = ["0.0.0.0/0"]
}
