output "cluster_endpoint" {
  description = "Endpoint URL for the EKS Kubernetes API server"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the EKS cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for the EKS cluster (used to create IRSA roles)"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "Issuer URL of the IAM OIDC provider (without https://, used in IRSA trust policies)"
  value       = trimprefix(aws_iam_openid_connect_provider.this.url, "https://")
}

# TODO: Replace the placeholder ARN below with a reference to the actual
# aws_secretsmanager_secret resource once it is defined (e.g. for storing
# the generated kubeconfig). Example:
#   value = aws_secretsmanager_secret.kubeconfig.arn
output "kubeconfig_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret that stores the cluster kubeconfig"
  value       = "arn:aws:secretsmanager:us-east-1:123456789012:secret:eks-kubeconfig-PLACEHOLDER"
}
