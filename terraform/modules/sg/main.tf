resource "aws_security_group" "fivem" {
  name        = "${var.project}-${var.env}-fivem-sg"
  description = "Security group for FiveM server"
  vpc_id      = var.vpc_id

  # SSH
  ingress {
    description = "SSH from admin IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  # FiveM TCP
  ingress {
    description = "FiveM TCP"
    from_port   = 30120
    to_port     = 30120
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # FiveM UDP (+ Mumble Voice)
  ingress {
    description = "FiveM UDP / Mumble Voice"
    from_port   = 30120
    to_port     = 30120
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # txAdmin Web UI (内部アクセスのみ)
  ingress {
    description = "txAdmin Web UI"
    from_port   = 40120
    to_port     = 40120
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  # Whitelist API
  ingress {
    description = "Whitelist FastAPI"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = var.api_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.env}-fivem-sg"
    Environment = var.env
    Project     = var.project
  }
}
