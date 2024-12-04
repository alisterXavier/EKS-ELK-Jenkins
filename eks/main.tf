resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = var.eks_role_arn
  vpc_config {
    endpoint_public_access = true
    public_access_cidrs    = ["0.0.0.0/0"]
    subnet_ids             = var.private_subnet_ids
  }
}

# resource "aws_eks_fargate_profile" "fargate_profile" {
#   cluster_name           = aws_eks_cluster.eks_cluster.name
#   fargate_profile_name   = "thunder"
#   pod_execution_role_arn = var.pod_execution_role_arn
#   subnet_ids             = var.private_subnet_ids
#   selector {
#     namespace = "thunder"
#   }

#   tags = {
#     Name = "Thunder"
#   }
# }

resource "aws_eks_node_group" "eks_node_group" {
  node_group_name = "thunder"
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_role_arn   = var.node_role.arn
  subnet_ids      = var.public_subnet_ids
  scaling_config {
    desired_size = 3
    min_size     = 1
    max_size     = 10
  }
  ami_type       = "AL2_x86_64"
  capacity_type  = "ON_DEMAND"
  disk_size      = 100
  instance_types = ["t3.large"]
  labels = {
    node-type = "ec2"
  }
  tags = {
    Name = "Thunder"
    "k8s.io/cluster-autoscaler/enabled" = "true"
    "k8s.io/cluster-autoscaler/thunder" = "owned"
  }
}
