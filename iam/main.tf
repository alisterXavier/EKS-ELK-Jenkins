#EKS Cluster
resource "aws_iam_role" "EksRole" {
  name = "EksRole"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Principal : {
          Service : "eks.amazonaws.com"
        },
        Action : "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.EksRole.name
}

#Fargate Role
resource "aws_iam_role" "pod_execution_role" {
  name = "pod_execution_role_arn"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}
resource "aws_iam_role_policy_attachment" "AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.pod_execution_role.name
}

#Node Group Role
resource "aws_iam_role" "node_role" {
  name = "eks-node-group"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}
resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_role.name
}
resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_role.name
}
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_role.name
}
resource "aws_iam_policy" "eks_csi_drive_policy" {
  policy = file("./iam/ebs_csi_policy.json")
  name   = "AmazonEBSCSIDriverPolicy"
}
resource "aws_iam_policy" "fluentbit_policy" {
  name = "OpensearchAccessForFluentBit"
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Action : ["es:ESHttp*"],
        Resource : "arn:aws:es:${var.region}:${var.account_id}:domain/${var.opensearch_domain_name}/*",
        Effect : "Allow"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "AmazonEBSCSIDriverPolicyAttachment" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
resource "aws_iam_role_policy_attachment" "AmazonFluentBitPolicyAttachment" {
  role       = aws_iam_role.node_role.name
  policy_arn = aws_iam_policy.FluentBitRolePolicy.arn
}


data "tls_certificate" "eks" {
  url = var.oidc_issuer
}
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = var.oidc_issuer
}
data "aws_iam_policy_document" "aws_eks_controller_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller", "system:serviceaccount:kube-system:cluster-autoscaler-controller", "system:serviceaccount:kube-system:fluent-bit-controller"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

#EKS LoadBalancer Role
resource "aws_iam_role" "aws_load_balancer_controller" {
  assume_role_policy = data.aws_iam_policy_document.aws_eks_controller_assume_role_policy.json
  name               = "AmazonEKSLoadBalancerControllerRole"
}
resource "aws_iam_policy" "aws_load_balancer_controller" {
  policy = file("./iam/AWSLoadBalancerController.json")
  name   = "AWSLoadBalancerControllerIAMPolicy"
}
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_attach" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

#EKS AutoScaler Role
resource "aws_iam_role" "aws_eks_cluster_autoscaler" {
  name               = "AmazonEKSAutoScalerRole"
  assume_role_policy = data.aws_iam_policy_document.aws_eks_controller_assume_role_policy.json
}
resource "aws_iam_policy" "aws_eks_cluster_autoscaler_policy" {
  name = "aws_eks_cluster_autoscaler_policy"
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Action : [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeInstanceTypes",
          "autoscaling:UpdateAutoScalingGroup"
        ],
        Resource : "*",
        Effect : "Allow"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "eks_cluster_autoscaler_policy_attachment" {
  role       = aws_iam_role.aws_eks_cluster_autoscaler.name
  policy_arn = aws_iam_policy.aws_eks_cluster_autoscaler_policy.arn
}

#Cognito Auth Role
resource "aws_iam_role" "authenticated_role" {
  name = "Cognito_Authenticated_Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          "StringEquals" = {
            "cognito-identity.amazonaws.com:aud" = var.identity_pool_id
          },
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      },
    ]
  })
}
resource "aws_iam_policy" "authenticated_policy" {
  name = "CognitoAuthenticatedPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "cognito-identity:GetCredentialsForIdentity"
        Resource = ["*"]
      },
    ]
  })
}
resource "aws_iam_role_policy_attachment" "attach_authenticated_policy" {
  role       = aws_iam_role.authenticated_role.name
  policy_arn = aws_iam_policy.authenticated_policy.arn
}

# Opensearch Role
resource "aws_iam_role" "cognito_for_opensearch_role" {
  name = "CognitoAccessForOpenSearch"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "opensearchservice.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "cognito_for_opensearch_role_attachment" {
  role       = aws_iam_role.cognito_for_opensearch_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonOpenSearchServiceCognitoAccess"
}

# Opensearch Service Linked Role
# resource "aws_iam_service_linked_role" "opensearch_service_linked_role" {
#   tags = {
#     Name = "AmazonOpenSearchServiceRoleThunder"
#   }
#   aws_service_name = "opensearchservice.amazonaws.com"
# }

# FluentBit
resource "aws_iam_role" "FluentBitRole" {
  name               = "FluentBitRole"
  assume_role_policy = data.aws_iam_policy_document.aws_eks_controller_assume_role_policy.json
}
resource "aws_iam_policy" "FluentBitRolePolicy" {
  name = "FluentBitRolePolicy"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "es:ESHttp*"
          ],
          "Resource" : "arn:aws:es:${var.region}:${var.account_id}:domain/${var.opensearch_domain_name}",
          "Effect" : "Allow"
        }
      ]
    }
  )
}
