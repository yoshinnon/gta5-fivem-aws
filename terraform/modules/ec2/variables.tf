variable "project" { type = string }
variable "env" { type = string }
variable "ami_id" { type = string }
variable "instance_type" { type = string }
variable "subnet_id" { type = string }
variable "security_group_id" { type = string }
variable "key_name" { type = string }
variable "eip_allocation_id" { type = string }
variable "availability_zone" { type = string }
variable "use_dedicated_host" {
  type    = bool
  default = false
}
variable "root_volume_size" {
  type    = number
  default = 30
}
variable "data_volume_size" {
  type    = number
  default = 100
}
variable "alarm_sns_arns" {
  type    = list(string)
  default = []
}
