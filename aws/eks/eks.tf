
module "eks" {
  count = local.eks_enabled ? 1 : 0

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.6.1"

  name                                     = var.cluster_name
  kubernetes_version                       = "1.34"
  enable_cluster_creator_admin_permissions = true
  endpoint_public_access                   = true
  endpoint_private_access                  = true

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids # Cluster control plane knows about these subnets

  enable_irsa = true # OIDC/IAM for Service Accounts

  # https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/v1.22.0/amazon-eks-addons/
  # Without this, CoreDNS and Kube-Proxy may fail to install
  addons = {
    coredns = {}

    kube-proxy = {}

    eks-pod-identity-agent = {
      before_compute = true
    }

    vpc-cni = {
      before_compute = true
    }

    # Community addons: https://docs.aws.amazon.com/eks/latest/userguide/community-addons.html
    # https://repost.aws/knowledge-center/eks-metrics-server
    # Check the API: kubectl describe apiservices.apiregistration.k8s.io v1beta1.metrics.k8s.io
    metrics-server = {} # 10251 port is used in default - conflict with EKS security
    # kube-state-metrics = {}

    aws-ebs-csi-driver = {
      pod_identity_association = [
        {
          role_arn        = module.ebs_pod_identity[0].iam_role_arn
          service_account = "ebs-csi-controller-sa"
        }
      ]
      preserve = true
    }
  }

  # Must be add this extra rule to allow EKS control plane to addon metrics-server secure-port 10251
  # https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest#input_node_security_group_additional_rules
  node_security_group_additional_rules = {
    allow_cp_to_metrics_server_10251 = {
      description                   = "Allow EKS control plane to metrics-server secure-port 10251"
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 10251
      to_port                       = 10251
      source_cluster_security_group = true
    }
    # THIS RULE IS NEEDED FOR ALLOWING INGRESS TRAFFIC TO WORKLOADS (NODES) FROM OUTSIDE THE CLUSTER
    allow_access_node_port_from_all_80_1 = {
      description = "Allow all traffic from outside to application NodePort 30080"
      type        = "ingress"
      protocol    = "tcp"
      from_port   = 30080
      to_port     = 30080
      cidr_blocks = ["0.0.0.0/0"]
    }
    allow_access_node_port_from_all_80_2 = {
      description = "Allow all traffic from outside to Grafana NodePort 30300"
      type        = "ingress"
      protocol    = "tcp"
      from_port   = 30300
      to_port     = 30300
      cidr_blocks = ["0.0.0.0/0"]
    }
    allow_dns_udp_egress = {
      description = "Allow DNS UDP queries to Route53 resolver"
      type        = "egress"
      protocol    = "udp"
      from_port   = 53
      to_port     = 53
      cidr_blocks = ["0.0.0.0/0"]
    }

    allow_dns_tcp_egress = {
      description = "Allow DNS TCP queries to Route53 resolver"
      type        = "egress"
      protocol    = "tcp"
      from_port   = 53
      to_port     = 53
      cidr_blocks = ["0.0.0.0/0"]
    }
    # Mandatory rule for node-to-node communication within the cluster
    allow_node_to_node_sg = {
      description = "Allow all traffic between nodes (node-to-node communication)"
      type        = "ingress"
      protocol    = "-1" # all protocols
      from_port   = 0
      to_port     = 0
      self        = true # Allow traffic within the same security group (nodes are in the same SG)
      #source_security_group_id = "sg-096685963f18ac89f" # Replace with your node security group ID
      #source_cluster_security_group = true # This is not enough
      #cidr_blocks = [data.aws_vpc.default.cidr_block] # This would allow all VPC traffic, which is too broad
    }
  }

  eks_managed_node_groups = local.eks_np_type == "public" ? {
    default_public_nodes = local.public_np
    } : local.eks_np_type == "private" ? {
    private_nodes = local.private_np
    } : local.eks_np_type == "both" ? {
    default_public_nodes = local.public_np
    private_nodes        = local.private_np
  } : null

  #eks_managed_node_groups = {
  #   default_public_nodes = contains(["public", "both"], local.eks_np_type) ? local.public_np : null

  #   private_nodes = contains(["private", "both"], local.eks_np_type) ? local.private_np : null
  # }

  tags = {
    Name        = var.cluster_name
    Environment = "dev"
  }
}

# Required for Pod Identity (AWS authentication without 'aws configure') -> PREREQUISITE
module "pod_identity" {
  count  = local.eks_enabled ? 1 : 0
  source = "../modules/base_pod_identity"

  eks_cluster_name       = module.eks[0].cluster_name
  target_namespace       = "default"
  target_service_account = "aws-cli-sa"
}

# Required for EBS CSI Driver Pod Identity -> PREREQUISITE
module "ebs_pod_identity" {
  count = local.eks_enabled ? 1 : 0

  source = "../modules/ebs_pod_identity"

  eks_cluster_name       = module.eks[0].cluster_name
  target_namespace       = "kube-system"
  target_service_account = "ebs-csi-controller-sa"
}
