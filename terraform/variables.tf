variable "aws_region" {
  description = "AWS region where the EKS cluster will be provisioned"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

# ---------------------------------------------------------------------------
# Pre-existing VPC — subnets and VPC ID must be supplied at plan time.
# ---------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID of the pre-existing VPC where the EKS cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs (public or private) for the EKS control plane ENIs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the Karpenter Fargate profile"
  type        = list(string)
}

# ---------------------------------------------------------------------------
# Remote state — values must be set before running terraform init
# ---------------------------------------------------------------------------

variable "state_bucket_name" {
  description = "Name of the S3 bucket used for Terraform remote state. Must be pre-created before running terraform init."
  type        = string
}

variable "state_lock_table" {
  description = "Name of the DynamoDB table used for Terraform state locking. Must be pre-created before running terraform init."
  type        = string
}
