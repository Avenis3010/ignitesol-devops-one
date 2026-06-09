# Creates the app namespace with env label and a NetworkPolicy
# that blocks all ingress from the opposite environment.

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.env
    labels = {
      environment = var.env
      project     = lookup(var.tags, "Project", "central-platform")
      managed-by  = "terraform"
    }
  }
}

resource "kubernetes_network_policy" "deny_other_env" {
  metadata {
    name      = "deny-other-env"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    pod_selector {} # applies to all pods in this namespace

    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_expressions {
            key      = "environment"
            operator = "NotIn"
            values   = [var.env == "prod" ? "dev" : "prod"]
          }
        }
      }
    }
  }
}
