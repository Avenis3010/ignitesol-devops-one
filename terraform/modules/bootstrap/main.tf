# ── ArgoCD ────────────────────────────────────────────────────────────────────
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.3.4"
  namespace        = "argocd"
  create_namespace = true

  set {
    name  = "global.env"
    value = var.env
  }

  # Disable dex (SSO) for simplicity; re-enable with proper config for prod SSO
  set {
    name  = "dex.enabled"
    value = "false"
  }
}

# ── External Secrets Operator ─────────────────────────────────────────────────
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.9.19"
  namespace        = "external-secrets"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  # IRSA — the ESO controller pod assumes this role to read Secrets Manager
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.eso_irsa_role_arn
  }
}

# ── AWS Load Balancer Controller (Ingress) ────────────────────────────────────
resource "helm_release" "aws_lb_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = "1.8.1"
  namespace        = "kube-system"
  create_namespace = false

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  # IRSA for ALB controller
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.alb_irsa_role_arn
  }
}

# ── kube-prometheus-stack (Prometheus + Grafana + AlertManager) ───────────────
resource "helm_release" "monitoring" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "61.3.0"
  namespace        = "monitoring"
  create_namespace = true

  # Lightweight values — disable persistence for dev, enable for prod
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = var.env == "prod" ? "30d" : "7d"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec"
    value = ""
  }

  set {
    name  = "grafana.adminPassword"
    value = "changeme-set-via-secret"  # override via values file or ESO in production
  }

  set {
    name  = "grafana.env.GF_SERVER_ROOT_URL"
    value = "%(protocol)s://%(domain)s/grafana"
  }
}
