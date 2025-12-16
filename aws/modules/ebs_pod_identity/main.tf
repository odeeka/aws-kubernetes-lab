# POD IDENTITY LAB RESOURCES - IAM Role, Role Policy Attachment, Pod Identity Association
# Create trust role for EKS Pod to assume
resource "aws_iam_role" "ebs_csi_role" {
  name        = "EKS-PodIdentity-EBS-CSI-Driver-Role"
  description = "Allows pods running in Amazon EKS cluster to access AWS resources"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

# Add EBS CSI policy to the role
resource "aws_iam_role_policy_attachment" "ebs_csi_policy_attach" {
  role       = aws_iam_role.ebs_csi_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attach" {
  role       = aws_iam_role.ebs_csi_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Create EKS - Acccess - Pod Identity Association
# Role + Namespace + Service Account
# resource "aws_eks_pod_identity_association" "aws_cli_pod_identity" {
#   cluster_name      = var.eks_cluster_name
#   namespace         = var.target_namespace
#   service_account   = "ebs-csi-controller-sa"
#   role_arn          = aws_iam_role.aws_cli_role.arn
# }

# After this you can create a pod using this Service Account to access S3 with the assigned role permissions
# kubectl apply -f pod.yaml
# POD IDENTITY LAB RESOURCES END
