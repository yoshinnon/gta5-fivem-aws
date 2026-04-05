resource "aws_iam_role" "fivem_ec2" {
  name = "${var.project}-${var.env}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Environment = var.env
    Project     = var.project
  }
}

# SSM Session Manager (SSH不要のアクセス手段)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.fivem_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Logs
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.fivem_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "fivem_ec2" {
  name = "${var.project}-${var.env}-ec2-profile"
  role = aws_iam_role.fivem_ec2.name
}
