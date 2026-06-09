locals {
  oidc_subject = [
    for ns in var.namespaces :
    "system:serviceaccount:${ns}:external-secrets-sa"
  ]
}

resource "aws_iam_role" "eso" {
  name = "${var.project_name}-eso-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "${var.oidc_provider_url}:sub" = local.oidc_subject
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "eso_secrets" {
  name = "eso-secrets-read"
  role = aws_iam_role.eso.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = var.secret_arns
    }]
  })
}

output "role_arn" {
  value = aws_iam_role.eso.arn
}
