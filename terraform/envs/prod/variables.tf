variable "project_name"  { type = string; default = "central-platform" }
variable "vpc_cidr"      { type = string; default = "10.1.0.0/16" }
variable "aws_region"    { type = string }
variable "db_password"   { type = string; sensitive = true }
variable "origin_domain" { type = string }
variable "github_repo"   { type = string; default = "Avenis3010/ignite-solutions" }
