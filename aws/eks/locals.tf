locals {

  # NatGW + EIP + Private route
  nat = false

  eks_enabled = var.eks_enabled
  eks_np_type = "public" # public | private | both

  public_np = {
    desired_size   = 2
    min_size       = 2
    max_size       = 3
    instance_types = ["t3.small"]
    ami_type       = "AL2023_x86_64_STANDARD"
    capacity_type  = "SPOT"
    subnet_ids     = data.aws_subnets.public.ids

    labels = {
      node-type   = "public"
      environment = "dev"
      zone        = "frontend"
    }
  }

  private_np = {
    desired_size   = 2
    min_size       = 2
    max_size       = 3
    instance_types = ["t3.small"]
    ami_type       = "AL2023_x86_64_STANDARD"
    capacity_type  = "SPOT"
    subnet_ids     = data.aws_subnets.private.ids
    labels = {
      node-type   = "private"
      environment = "dev"
      zone        = "backend"
    }
  }

  rds_enabled = var.rds_enabled
  rds_name    = "rdsdemo"
}
