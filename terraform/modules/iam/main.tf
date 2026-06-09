locals {
  oidc_url   = var.oidc_provider_url
  branch_ref = var.env == "prod" ? "refs/heads/production" : "refs/heads/dev"
  prefix     = "${var.project_name}-${var.env}"
}

# The GitHub OIDC provider is account-scoped (one per AWS account).
# On first apply (dev env) it is created. On subsequent applies it is
# looked up via data source to avoid duplicate-resource errors.
# To import an existing one:
#   terraform import module.iam.aws_iam_openid_connect_provider.github <arn>
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  lifecycle { prevent_destroy = true }
}

# ── BACKEND ROLE — ECR push + EKS describe only ───────────────────────────────
resource "aws_iam_role" "backend" {
  name = "${local.prefix}-backend-cicd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "${local.oidc_url}:aud" = "sts.amazonaws.com" }
        StringLike   = { "${local.oidc_url}:sub" = "repo:${var.github_repo}:ref:${local.branch_ref}" }
      }
    }]
  })

  tags = { Role = "backend-cicd", Environment = var.env }
}

resource "aws_iam_role_policy" "backend" {
  name = "${local.prefix}-backend-cicd-policy"
  role = aws_iam_role.backend.id

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
          "ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart",
          "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"
        ]
        Resource = var.ecr_repo_arns
      },
      {
        Sid      = "EKSDescribe"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster", "eks:ListClusters"]
        Resource = [var.eks_cluster_arn]
      }
    ]
  })
}

# ── FRONTEND ROLE — this env's S3 bucket + CloudFront only ───────────────────
resource "aws_iam_role" "frontend" {
  name = "${local.prefix}-frontend-cicd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "${local.oidc_url}:aud" = "sts.amazonaws.com" }
        StringLike   = { "${local.oidc_url}:sub" = "repo:${var.github_repo}:ref:${local.branch_ref}" }
      }
    }]
  })

  tags = { Role = "frontend-cicd", Environment = var.env }
}

resource "aws_iam_role_policy" "frontend" {
  name = "${local.prefix}-frontend-cicd-policy"
  role = aws_iam_role.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3Deploy"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [var.s3_bucket_arn, "${var.s3_bucket_arn}/*"]
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

# ── DATABASE ROLE — EKS describe + read THIS env's secret only ────────────────
# No RDS direct access. No Secrets Manager write. No S3. No ECR.
resource "aws_iam_role" "database" {
  name = "${local.prefix}-database-cicd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "${local.oidc_url}:aud" = "sts.amazonaws.com" }
        StringLike   = { "${local.oidc_url}:sub" = "repo:${var.github_repo}:ref:${local.branch_ref}" }
      }
    }]
  })

  tags = { Role = "database-cicd", Environment = var.env }
}

resource "aws_iam_role_policy" "database" {
  name = "${local.prefix}-database-cicd-policy"
  role = aws_iam_role.database.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EKSDescribe"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster", "eks:ListClusters"]
        Resource = [var.eks_cluster_arn]
      },
      {
        Sid      = "SecretsReadThisEnvOnly"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [var.secrets_manager_secret_arn]
      }
    ]
  })
}
