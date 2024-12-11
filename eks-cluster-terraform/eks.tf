data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    } 
  }
}

data "aws_vpc" "eks_default_vpc" {
  default = true
}

data "aws_subnets" "eks_public_subnet" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.eks_default_vpc.id]
  }
}

data "aws_subnet" "by_id" {
  for_each = toset(data.aws_subnets.eks_public_subnet.ids)
  id       = each.value
}

locals {
  filtered_subnet_ids = [
    for id, subnet in data.aws_subnet.by_id :
    id if subnet.availability_zone != "us-east-1e"
  ]
}

resource "aws_iam_role" "eks_role" {
  name = "EKS-Cluster-Role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_role_policy_attachment" {
  role = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "eks_cluster" {
  name = "EKS-Cluster-Cloud"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = local.filtered_subnet_ids
  }

  depends_on = [ 
    aws_iam_role_policy_attachment.example-AmazonEKSWorkerNodePolicy
   ]
}

resource "aws_iam_role" "eks_node_iam_role" {
  name = "eks-node-group-cloud"

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

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role = aws_iam_role.eks_node_iam_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_iam_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_iam_role.name
}

resource "aws_eks_node_group" "eks_cluster_node_group" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  node_group_name = "Node-Cloud"
  node_role_arn = aws_iam_role.eks_node_iam_role.arn

  subnet_ids = local.filtered_subnet_ids

  scaling_config {
    desired_size = 1
    max_size = 2
    min_size = 1
  }

  instance_types = ["t2.medium"]

  depends_on = [ 
    aws_iam_role_policy_attachment.example-AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.example-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.example-AmazonEKSWorkerNodePolicy
  ]

}