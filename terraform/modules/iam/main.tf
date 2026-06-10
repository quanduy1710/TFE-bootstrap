###############################################################################
# EKS Cluster IAM Role
###############################################################################

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.cluster_name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json

  tags = {
    Name = "${var.cluster_name}-eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

###############################################################################
# EKS Node Group IAM Role
###############################################################################

data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node" {
  name               = "${var.cluster_name}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json

  tags = {
    Name = "${var.cluster_name}-eks-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

###############################################################################
# Fargate Pod Execution Role
#   Required for any Fargate profile (including the Karpenter profile).
###############################################################################

data "aws_iam_policy_document" "fargate_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fargate_pod_execution" {
  name               = "${var.cluster_name}-fargate-pod-execution-role"
  assume_role_policy = data.aws_iam_policy_document.fargate_assume_role.json

  tags = {
    Name = "${var.cluster_name}-fargate-pod-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "fargate_pod_execution_policy" {
  role       = aws_iam_role.fargate_pod_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

###############################################################################
# ArgoCD IRSA Role
#   Grants ArgoCD's service account the ability to assume an AWS IAM role.
#   Attach additional policies here if ArgoCD needs AWS API access
#   (e.g., Secrets Manager for ApplicationSet secret generators).
###############################################################################

data "aws_iam_policy_document" "argocd_irsa_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      # Covers both the argocd-server and argocd-application-controller service accounts.
      values = [
        "system:serviceaccount:argocd:argocd-server",
        "system:serviceaccount:argocd:argocd-application-controller",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "argocd" {
  name               = "${var.cluster_name}-argocd-irsa-role"
  assume_role_policy = data.aws_iam_policy_document.argocd_irsa_assume_role.json

  tags = {
    Name = "${var.cluster_name}-argocd-irsa-role"
  }
}

# TODO: attach policies if ArgoCD needs AWS API access, e.g.:
# resource "aws_iam_role_policy_attachment" "argocd_secrets_manager" {
#   role       = aws_iam_role.argocd.name
#   policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
# }

###############################################################################
# Karpenter IRSA Role
#   Karpenter requires broad EC2 and IAM permissions to launch and terminate
#   nodes on behalf of the cluster.
###############################################################################

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "karpenter_irsa_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "karpenter" {
  name               = "${var.cluster_name}-karpenter-irsa-role"
  assume_role_policy = data.aws_iam_policy_document.karpenter_irsa_assume_role.json

  tags = {
    Name = "${var.cluster_name}-karpenter-irsa-role"
  }
}

data "aws_iam_policy_document" "karpenter_controller" {
  # Allow Karpenter to pass the node IAM role when launching instances
  statement {
    sid     = "PassNodeIAMRole"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster_name}-eks-node-role",
    ]
  }

  # EC2 permissions for node lifecycle management
  statement {
    sid    = "EC2NodeLifecycle"
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeLaunchTemplates",
      "ec2:CreateLaunchTemplate",
      "ec2:DeleteLaunchTemplate",
      "ec2:CreateFleet",
      "ec2:CreateTags",
    ]
    resources = ["*"]
  }

  # SSM — Karpenter reads EKS-optimised AMI IDs from SSM
  statement {
    sid       = "SSMAMILookup"
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:*:*:parameter/aws/service/eks/optimized-ami/*"]
  }

  # EKS — needed for Karpenter to join nodes to the cluster
  statement {
    sid    = "EKSNodeAccess"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
    ]
    resources = [
      "arn:aws:eks:*:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}",
    ]
  }

  # Pricing API — used to select the cheapest instance type
  statement {
    sid       = "PricingReadOnly"
    effect    = "Allow"
    actions   = ["pricing:GetProducts"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "${var.cluster_name}-karpenter-controller-policy"
  description = "Permissions required by the Karpenter controller to manage EC2 nodes"
  policy      = data.aws_iam_policy_document.karpenter_controller.json
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}
