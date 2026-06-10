variable "cluster_name" {
  description = "Name of the EKS cluster; used to namespace IAM role names and policies"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster's IAM OIDC provider (used to create IRSA trust policies)"
  type        = string
}

variable "oidc_provider_url" {
  description = "Issuer URL of the EKS OIDC provider without https:// prefix (used in IRSA trust policy conditions)"
  type        = string
}
