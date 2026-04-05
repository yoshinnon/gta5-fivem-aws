# -----------------------------------------------
# Dedicated Host (prd のみ作成)
# -----------------------------------------------
resource "aws_ec2_host" "main" {
  count             = var.use_dedicated_host ? 1 : 0
  instance_type     = var.instance_type
  availability_zone = var.availability_zone
  auto_placement    = "off"

  tags = {
    Name        = "${var.project}-${var.env}-dedicated-host"
    Environment = var.env
    Project     = var.project
  }
}

# -----------------------------------------------
# EC2 Instance
# -----------------------------------------------
resource "aws_instance" "fivem" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name

  # Dedicated Host 設定 (prd のみ)
  tenancy  = var.use_dedicated_host ? "host" : "default"
  host_id  = var.use_dedicated_host ? aws_ec2_host.main[0].id : null

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project}-${var.env}-root-vol"
    }
  }

  # FiveMデータ用追加ボリューム
  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_type           = "gp3"
    volume_size           = var.data_volume_size
    delete_on_termination = false
    encrypted             = true

    tags = {
      Name = "${var.project}-${var.env}-data-vol"
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/userdata.sh.tpl", {
    env = var.env
  }))

  tags = {
    Name        = "${var.project}-${var.env}-fivem"
    Environment = var.env
    Project     = var.project
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# -----------------------------------------------
# EIP Association
# -----------------------------------------------
resource "aws_eip_association" "main" {
  instance_id   = aws_instance.fivem.id
  allocation_id = var.eip_allocation_id
}

# -----------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project}-${var.env}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "CPU utilization is too high"
  alarm_actions       = var.alarm_sns_arns

  dimensions = {
    InstanceId = aws_instance.fivem.id
  }
}
