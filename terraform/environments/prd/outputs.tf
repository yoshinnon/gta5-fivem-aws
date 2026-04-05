output "server_public_ip" {
  description = "FiveM サーバー EIP"
  value       = module.vpc.eip_public_ip
}

output "instance_id" {
  description = "EC2 インスタンス ID"
  value       = module.ec2.instance_id
}

output "global_accelerator_ips" {
  description = "Global Accelerator の静的 IP (プレイヤーへ告知する IP)"
  value       = aws_globalaccelerator_accelerator.fivem.ip_sets[*].ip_addresses
}

output "connect_command" {
  description = "SSH 接続コマンド"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.vpc.eip_public_ip}"
}

output "txadmin_url" {
  description = "txAdmin URL"
  value       = "http://${module.vpc.eip_public_ip}:40120"
}

output "whitelist_api_url" {
  description = "Whitelist API URL"
  value       = "http://${module.vpc.eip_public_ip}:8000"
}

output "sns_topic_arn" {
  description = "アラート SNS トピック ARN"
  value       = aws_sns_topic.alerts.arn
}
