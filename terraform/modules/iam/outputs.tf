output "backend_dev_role_arn"   { value = aws_iam_role.backend_dev.arn }
output "backend_prod_role_arn"  { value = aws_iam_role.backend_prod.arn }
output "frontend_dev_role_arn"  { value = aws_iam_role.frontend_dev.arn }
output "frontend_prod_role_arn" { value = aws_iam_role.frontend_prod.arn }
output "database_dev_role_arn"  { value = aws_iam_role.database_dev.arn }
output "database_prod_role_arn" { value = aws_iam_role.database_prod.arn }
output "oidc_provider_arn"      { value = aws_iam_openid_connect_provider.github.arn }
