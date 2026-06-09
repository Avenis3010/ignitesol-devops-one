data "aws_caller_identity" "current" {}

# KMS key used to encrypt RDS storage and Secrets Manager secrets at rest
resource "aws_kms_key" "main" {
  description             = "${var.project_name}-${var.env} encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true   # rotate annually — AWS best practice

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAccountRoot"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-${var.env}"
  target_key_id = aws_kms_key.main.key_id
}

output "key_arn" { value = aws_kms_key.main.arn }
output "key_id"  { value = aws_kms_key.main.key_id }
