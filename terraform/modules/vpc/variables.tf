variable "project_name" {}
variable "vpc_cidr" {}
variable "aws_region" {}
variable "env" { type = string }
variable "tags" { type = map(string) }
