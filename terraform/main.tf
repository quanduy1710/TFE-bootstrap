terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# IAM — cluster and node roles needed before EKS cluster creation.
# OIDC-dependent roles (ArgoCD, Karpenter) are wired in after EKS creates
# the OIDC provider, using outputs from the eks module.
# ---------------------------------------------------------------------------
module "iam" {
  source            = "./modules/iam"
  cluster_name      = var.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}

# ---------------------------------------------------------------------------
# EKS cluster — creates the control plane, OIDC provider, and Fargate profile.
# VPC and subnets are pre-existing and passed in as variables.
# Node provisioning is handled by Karpenter (deployed via ArgoCD).
# ---------------------------------------------------------------------------
module "eks" {
  source                         = "./modules/eks"
  cluster_name                   = var.cluster_name
  cluster_version                = var.cluster_version
  vpc_id                         = var.vpc_id
  subnet_ids                     = var.subnet_ids
  private_subnet_ids             = var.private_subnet_ids
  cluster_role_arn               = module.iam.cluster_role_arn
  node_role_arn                  = module.iam.node_role_arn
  fargate_pod_execution_role_arn = module.iam.fargate_pod_execution_role_arn
}
