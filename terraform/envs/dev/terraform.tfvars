project_name  = "central-platform"
vpc_cidr      = "10.0.0.0/16"
aws_region    = "ap-south-1"
origin_domain = "central-platform-frontend.s3.amazonaws.com"
# db_password is passed via TF_VAR_db_password env var — never commit this value
