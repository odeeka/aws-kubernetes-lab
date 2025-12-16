output "public_subnets" {
  value = data.aws_subnets.public.ids
}

output "private_subnets" {
  value = data.aws_subnets.private.ids
}

output "eks_cluster_endpoint" {
  value = local.eks_enabled ? module.eks[0].cluster_endpoint : ""
}

output "eks_cluster_id" {
  value = local.eks_enabled ? module.eks[0].cluster_id : ""
}

output "eks_cluster_name" {
  value = local.eks_enabled ? module.eks[0].cluster_name : ""
}

output "rds_endpoint" {
  value = local.rds_enabled ? module.rds[0].db_instance_endpoint : ""
}

output "rds_id" {
  value = local.rds_enabled ? module.rds[0].db_instance_identifier : ""
}
