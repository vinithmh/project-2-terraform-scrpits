provider "aws" {
  region = "us-east-1"  # Change this to your desired AWS region
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name               = "my-vpc"
  cidr               = "10.0.0.0/16"
  azs                = ["us-east-1a", "us-east-1b"]
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_nat_gateway = true
  enable_vpn_gateway = true
  public_subnet_tags = {
    "map_public_ip_on_launch" = true
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
  map_public_ip_on_launch = true
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.0"
  cluster_name    = "revhire-cluster"
  cluster_version = "1.29"
  cluster_endpoint_public_access = true

  # EKS Addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.public_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = "t2.large"
  }

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    revhire-node = {
      min_size     = 1
      max_size     = 1
      desired_size = 1
      instance_types = ["t2.large"]
      capacity_type  = "ON_DEMAND"
    }
  }

  # Cluster access entry
  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
