resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true # TODO: restrict to known CIDR ranges for production
    # TODO: public_access_cidrs = ["<your-office-cidr>/32"]
  }

  tags = {
    Name = var.cluster_name
  }

  # Ensure IAM role is fully created before the cluster, to avoid race conditions.
  # The depends_on is added in the root module where the IAM role is wired in.
}

# ---------------------------------------------------------------------------
# OIDC provider — required for IRSA (ArgoCD, Karpenter, and other workloads)
# ---------------------------------------------------------------------------
data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.cluster_name}-oidc-provider"
  }
}

# ---------------------------------------------------------------------------
# EKS add-ons
#   Pin addon_version values to tested releases for your cluster_version.
# ---------------------------------------------------------------------------
# resource "aws_eks_addon" "coredns" {
#   cluster_name  = aws_eks_cluster.this.name
#   addon_name    = "coredns"
#   addon_version = "v1.11.1-eksbuild.4" # TODO: pin to validated version
# }
#
# resource "aws_eks_addon" "kube_proxy" {
#   cluster_name  = aws_eks_cluster.this.name
#   addon_name    = "kube-proxy"
#   addon_version = "v1.29.3-eksbuild.2" # TODO: pin to validated version
# }
#
# resource "aws_eks_addon" "vpc_cni" {
#   cluster_name  = aws_eks_cluster.this.name
#   addon_name    = "vpc-cni"
#   addon_version = "v1.18.1-eksbuild.1" # TODO: pin to validated version
# }

# ---------------------------------------------------------------------------
# Fargate profile for Karpenter
#   Karpenter runs on Fargate so it can provision worker nodes before any
#   EC2 nodes exist. The profile targets the karpenter namespace only.
# ---------------------------------------------------------------------------
resource "aws_eks_fargate_profile" "karpenter" {
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "karpenter"
  pod_execution_role_arn = var.fargate_pod_execution_role_arn
  subnet_ids             = var.private_subnet_ids

  selector {
    namespace = "karpenter"
  }

  tags = {
    Name = "${var.cluster_name}-fargate-karpenter"
  }
}
