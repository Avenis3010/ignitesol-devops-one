terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws        = { source = "hashicorp/aws";        version = "~> 5.0" }
    helm       = { source = "hashicorp/helm";       version = "~> 2.14" }
    kubernetes = { source = "hashicorp/kubernetes"; version = "~> 2.31" }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = { Environment = "dev", ManagedBy = "terraform" } }
}

# Helm + Kubernetes providers authenticate against the EKS cluster
# that is created in the same apply via module.eks.
# They are configured lazily — Terraform resolves them after EKS is up.
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}
