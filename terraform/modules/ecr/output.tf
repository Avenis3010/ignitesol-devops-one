output "backend_repo_url" { value = aws_ecr_repository.backend.repository_url }
output "backend_repo_arn" { value = aws_ecr_repository.backend.arn }
output "frontend_repo_arn" { value = aws_ecr_repository.frontend.arn }
