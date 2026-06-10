output "cluster_endpoint" {
  description = "EKS cluster API server endpoint URL"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "kubeconfig_arn" {
  description = "ARN of the Secrets Manager secret holding the kubeconfig"
  value       = module.eks.kubeconfig_secret_arn
}

output "argocd_irsa_role_arn" {
  description = "ARN of the IRSA role to annotate ArgoCD service accounts with"
  value       = module.iam.argocd_irsa_role_arn
}

output "karpenter_irsa_role_arn" {
  description = "ARN of the IRSA role to annotate the Karpenter controller service account with"
  value       = module.iam.karpenter_irsa_role_arn
}
