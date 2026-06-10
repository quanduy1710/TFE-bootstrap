output "cluster_role_arn" {
  description = "ARN of the IAM role used by the EKS cluster control plane"
  value       = aws_iam_role.eks_cluster.arn
}

output "node_role_arn" {
  description = "ARN of the IAM role used by EKS worker nodes"
  value       = aws_iam_role.eks_node.arn
}

output "fargate_pod_execution_role_arn" {
  description = "ARN of the IAM role used by Fargate to execute pods"
  value       = aws_iam_role.fargate_pod_execution.arn
}

output "argocd_irsa_role_arn" {
  description = "ARN of the IRSA role for ArgoCD service accounts"
  value       = aws_iam_role.argocd.arn
}

output "karpenter_irsa_role_arn" {
  description = "ARN of the IRSA role for the Karpenter controller service account"
  value       = aws_iam_role.karpenter.arn
}
