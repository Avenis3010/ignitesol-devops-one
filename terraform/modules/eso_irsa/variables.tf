variable "project_name" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider_url" {
  type = string
}

variable "secret_arns" {
  type        = list(string)
  description = "List of Secrets Manager ARNs ESO may read"
}

variable "namespaces" {
  type    = list(string)
  default = ["dev", "prod"]
}
