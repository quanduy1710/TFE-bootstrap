variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster (e.g. \"1.29\")"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the EKS cluster will be placed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs (private) for the EKS control plane and node groups"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs used for the Karpenter Fargate profile"
  type        = list(string)
}

variable "cluster_role_arn" {
  description = "ARN of the IAM role for the EKS cluster control plane"
  type        = string
}

variable "node_role_arn" {
  description = "ARN of the IAM role for EKS worker nodes"
  type        = string
}

variable "fargate_pod_execution_role_arn" {
  description = "ARN of the IAM role used by Fargate to execute pods (required for the Karpenter Fargate profile)"
  type        = string
}
