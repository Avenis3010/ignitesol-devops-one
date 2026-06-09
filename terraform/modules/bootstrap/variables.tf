variable "env"                  { type = string }
variable "cluster_name"         { type = string }
variable "aws_region"           { type = string }
variable "vpc_id"               { type = string }
variable "eso_irsa_role_arn"    { type = string }
variable "alb_irsa_role_arn"    { type = string }
variable "tags"                 { type = map(string) }
