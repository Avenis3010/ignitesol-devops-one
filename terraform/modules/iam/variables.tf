variable "project_name" {
  type = string
}

variable "github_repo" {
  type        = string
  description = "owner/repo, e.g. Avenis3010/ignite-solutions"
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider_url" {
  type = string
}

# Resource identifiers for scoped policies
variable "ecr_repo_arns" {
  type        = list(string)
  description = "ARNs of ECR repositories the backend roles may push to"
}

variable "s3_bucket_arn" {
  type        = string
  description = "ARN of the frontend S3 bucket"
}

variable "cloudfront_distribution_arn" {
  type        = string
  description = "ARN of the CloudFront distribution"
}

variable "eks_cluster_arn" {
  type        = string
  description = "ARN of the EKS cluster"
}

variable "secrets_manager_dev_arn" {
  type        = string
  description = "ARN of the dev RDS secret in Secrets Manager"
}

variable "secrets_manager_prod_arn" {
  type        = string
  description = "ARN of the prod RDS secret in Secrets Manager"
}
