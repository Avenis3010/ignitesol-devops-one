output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_backend_url" {
  value = module.ecr.backend_repo_url
}

output "rds_endpoint" {
  value = module.rds.rds_endpoint
}

output "cloudfront_url" {
  value = module.cloudfront.cloudfront_domain
}

# ── CI/CD Role ARNs — copy these into GitHub repository variables ─────────────
output "backend_dev_role_arn"   { value = module.iam.backend_dev_role_arn }
output "backend_prod_role_arn"  { value = module.iam.backend_prod_role_arn }
output "frontend_dev_role_arn"  { value = module.iam.frontend_dev_role_arn }
output "frontend_prod_role_arn" { value = module.iam.frontend_prod_role_arn }
output "database_dev_role_arn"  { value = module.iam.database_dev_role_arn }
output "database_prod_role_arn" { value = module.iam.database_prod_role_arn }
