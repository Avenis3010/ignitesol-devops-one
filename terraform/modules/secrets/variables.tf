variable "env"         { type = string }
variable "db_host"     { type = string }
variable "db_name"     { type = string; default = "platform" }
variable "db_user"     { type = string; default = "admin" }
variable "db_password" { type = string; sensitive = true }
variable "kms_key_arn" { type = string; description = "KMS CMK ARN for Secrets Manager encryption" }
