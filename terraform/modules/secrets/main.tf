resource "aws_secretsmanager_secret" "rds" {
  name                    = "platform/${var.env}/rds"
  recovery_window_in_days = 0
  kms_key_id              = var.kms_key_arn   # CWE-311: encrypt with CMK
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    DB_HOST     = var.db_host
    DB_NAME     = var.db_name
    DB_USER     = var.db_user
    DB_PASSWORD = var.db_password
  })
}

output "secret_arn" {
  value = aws_secretsmanager_secret.rds.arn
}
