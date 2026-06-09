variable "vpc_id" {}
variable "private_subnets" {}
variable "public_subnets" {}
variable "env"          { type = string }
variable "project_name" { type = string }
variable "tags"         { type = map(string) }
