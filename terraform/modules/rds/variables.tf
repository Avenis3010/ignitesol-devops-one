variable "subnet_ids"          { type = list(string) }
variable "vpc_id"               { type = string }
variable "env"                  { type = string }
variable "project_name"         { type = string }
variable "db_password"          { sensitive = true }
variable "allowed_cidr_blocks"  { type = list(string); default = [] }
variable "tags"                 { type = map(string) }
