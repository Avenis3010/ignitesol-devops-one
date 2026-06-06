locals {
  env          = "dev"
  project_name = var.project_name

  tags = {
    Environment = "dev"
    Project     = var.project_name
    ManagedBy   = "terraform"
    Owner       = "platform-team"
  }
}

data "aws_caller_identity" "current" {}

# ── Infrastructure ────────────────────────────────────────────────────────────

module "vpc" {
  source       = "../../modules/vpc"
  env          = local.env
  project_name = local.project_name
  vpc_cidr     = var.vpc_cidr
  aws_region   = var.aws_region
  tags         = local.tags
}

module "eks" {
  source          = "../../modules/eks"
  env             = local.env
  project_name    = local.project_name
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  public_subnets  = module.vpc.public_subnets
  tags            = local.tags
}

module "ecr" {
  source       = "../../modules/ecr"
  env          = local.env
  project_name = local.project_name
  tags         = local.tags
}

module "rds" {
  source              = "../../modules/rds"
  env                 = local.env
  project_name        = local.project_name
  subnet_ids          = module.vpc.private_subnets
  db_password         = var.db_password
  vpc_id              = module.vpc.vpc_id
  allowed_cidr_blocks = [var.vpc_cidr]
  tags                = local.tags
}

module "s3" {
  source       = "../../modules/s3"
  env          = local.env
  project_name = local.project_name
  tags         = local.tags
}

module "cloudfront" {
  source           = "../../modules/cloudfront"
  env              = local.env
  project_name     = local.project_name
  s3_bucket_domain = module.s3.bucket_domain_name
  origin_domain    = var.origin_domain
  tags             = local.tags
}

# ── Secrets Manager ───────────────────────────────────────────────────────────

module "secrets" {
  source      = "../../modules/secrets"
  env         = local.env
  db_host     = module.rds.db_endpoint
  db_password = var.db_password
}

# ── IAM — IRSA roles ──────────────────────────────────────────────────────────

module "eso_irsa" {
  source            = "../../modules/eso_irsa"
  project_name      = local.project_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  secret_arns       = [module.secrets.secret_arn]
  namespaces        = [local.env]
}

module "alb_irsa" {
  source            = "../../modules/alb_irsa"
  env               = local.env
  project_name      = local.project_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}

module "iam" {
  source       = "../../modules/iam"
  project_name = local.project_name
  github_repo  = var.github_repo
  env          = local.env

  oidc_provider_arn           = module.eks.oidc_provider_arn
  oidc_provider_url           = module.eks.oidc_provider_url
  ecr_repo_arns               = [module.ecr.backend_repo_arn, module.ecr.frontend_repo_arn]
  s3_bucket_arn               = module.s3.bucket_arn
  cloudfront_distribution_arn = module.cloudfront.distribution_arn
  eks_cluster_arn             = module.eks.cluster_arn
  secrets_manager_secret_arn  = module.secrets.secret_arn
}

# ── Kubernetes — namespace + network policy ───────────────────────────────────
# Depends on EKS being ready (kubernetes provider configured against it)

module "k8s_namespaces" {
  source = "../../modules/k8s_namespaces"
  env    = local.env
  tags   = local.tags

  depends_on = [module.eks]
}

# ── Bootstrap — ArgoCD, ESO, ALB Controller, Monitoring ──────────────────────

module "bootstrap" {
  source             = "../../modules/bootstrap"
  env                = local.env
  cluster_name       = module.eks.cluster_name
  aws_region         = var.aws_region
  vpc_id             = module.vpc.vpc_id
  eso_irsa_role_arn  = module.eso_irsa.role_arn
  alb_irsa_role_arn  = module.alb_irsa.role_arn
  tags               = local.tags

  depends_on = [module.eks, module.k8s_namespaces]
}
