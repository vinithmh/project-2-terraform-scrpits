# Eks cluster networking - Declaring the VPC module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "eks_vpc"
  cidr = var.vpc_cidr

  azs = var.aws_availability_zones
  public_subnets = var.public_subnets
  private_subnets = var.private_subnets

  enable_dns_hostnames = true
  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    "kubernetes.io/cluster/revhire-eks-cluster" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/revhire-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb" = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/revhire-eks-cluster" = "shared"
    "kubernetes.io/role/elb" = "1"
  }
}

# EKS Cluster - Referencing VPC module outputs
module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name = "revhire-cluster"
  cluster_version = 1.29

  # Use the output from the vpc module
  vpc_id = module.vpc.vpc_id
  # Use the list output from the vpc module
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    nodes = {
      min_size = var.min_size_node
      max_size = var.max_size_node
      desired_size = var.desired_size_node
      instance_type = ["t2.small"]
    }
  }

  tags = {
    Environment = "dev"
    Terraform = true
  }
}


