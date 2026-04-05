output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "eip_id" {
  value = aws_eip.main.id
}

output "eip_public_ip" {
  value = aws_eip.main.public_ip
}
