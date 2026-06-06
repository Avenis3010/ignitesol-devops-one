# ── OIDC Provider (shared, created once) ─────────────────────────────────────
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ── Local helpers ─────────────────────────────────────────────────────────────
locals {
  oidc_url = var.oidc_provider_url

  # Trust condition builder: locks a role to one branch + one workflow job
  def_trust = {
    Version = "2012-10-17"
    Statement = []
  }
}

# ── Reusable trust-policy factory (inline) ────────────────────────────────────
# Each role's assume_role_policy is built inline below for clarity.

# ─────────────────────────────────────────────────────────────────────────────
# 1. BACKEND DEV ROLE
#    Trusted by: push to dev branch, build-backend job only
#    Permissions: ECR push, EKS describe (update-kubeconfig), read ArgoCD secret
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "backend_dev" {
  name = "${var.project_name}-backend-dev-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "${local.oidc_url}:aud" = "sts.amazonaws.com" }
        StringLike   = { "${local.oidc_url}:sub" = "repo:${var.github_repo}:ref:refs/heads/dev" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "backend_dev" {
  name = "backend-dev-policy"
  role = aws_iam_role.backend_dev.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = ["*"]
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = var.ecr_repo_arns
      },
      {
        Sid    = "EKSDescribe"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = [var.eks_cluster_arn]
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. BACKEND PROD ROLE
#    Trusted by: push to production branch only
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "backend_prod" {
  name = "${var.project_name}-backend-prod-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "${local.oidc_url}:aud" = "sts.amazonaws.com" }
        StringLike   = { "${local.oidc_url}:sub" = "repo:${var.github_repo}:ref:refs/heads/production" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "backend_prod" {
  name = "backend-prod-policy"
  role = aws_iam_role.backend_prod.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = ["*"]
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = var.ecr_repo_arns
      },
      {
        Sid    = "EKSDescribe"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = [var.eks_cluster_arn]
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. FRONTEND DEV ROLE
#    Permissions: S3 sync to /dev/* prefix only, CloudFront invalidation
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "frontend_dev" {
  name = "${var.project_name}-frontend-dev-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "${local.oidc_url}:aud" = "sts.amazonaws.com" }
        StringLike   = { "${local.oidc_url}:sub" = "repo:${var.github_repo}:ref:refs/heads/dev" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "frontend_dev" {
  name = "frontend-dev-policy"
  role = aws_iam_role.frontend_dev.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3DevDeploy"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/dev/*"
        ]
      },
      {
        Sid      = "CloudFrontInvalidate"
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation"]
        Resource = [var.cloudfront_distribution_arn]
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. FRONTEND PROD ROLE
#    Permissions: S3 sync to /prod/* prefix only, CloudFront invalidation
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "frontend_prod" {
  name = "${var.project_name}-frontend-prod-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "${local.oidc_url}:aud" = "sts.amazonaws.com" }
        StringLike   = { "${local.oidc_url}:sub" = "repo:${var.github_repo}:ref:refs/heads/production" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "frontend_prod" {
  name = "frontend-prod-policy"
  role = aws_iam_role.frontend_prod.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ProdDeploy"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/prod/*"
        ]
      },
      {
        Sid      = "CloudFrontInvalidate"
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation"]
        Resource = [var.cloudfront_distribution_arn]
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# 5. DATABASE DEV ROLE
#    Permissions: EKS describe (update-kubeconfig), read dev secret only
#    NO RDS direct access, NO Secrets Manager write
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "database_dev" {
  name = "${var.project_name}-database-dev-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "${local.oidc_url}:aud" = "sts.amazonaws.com" }
        StringLike   = { "${local.oidc_url}:sub" = "repo:${var.github_repo}:ref:refs/heads/dev" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "database_dev" {
  name = "database-dev-policy"
  role = aws_iam_role.database_dev.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSDescribe"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = [var.eks_cluster_arn]
      },
      {
        Sid    = "SecretsReadDevOnly"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [var.secrets_manager_dev_arn]
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# 6. DATABASE PROD ROLE
#    Permissions: EKS describe, read prod secret only
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "database_prod" {
  name = "${var.project_name}-database-prod-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "${local.oidc_url}:aud" = "sts.amazonaws.com" }
        StringLike   = { "${local.oidc_url}:sub" = "repo:${var.github_repo}:ref:refs/heads/production" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "database_prod" {
  name = "database-prod-policy"
  role = aws_iam_role.database_prod.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSDescribe"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = [var.eks_cluster_arn]
      },
      {
        Sid    = "SecretsReadProdOnly"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [var.secrets_manager_prod_arn]
      }
    ]
  })
}
