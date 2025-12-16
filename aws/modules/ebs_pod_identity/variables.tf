variable "eks_cluster_name" {
  type    = string
  default = "eksdemo"
}

variable "target_namespace" {
  type    = string
  default = "default"
}

variable "target_service_account" {
  type    = string
  default = "aws-cli-sa"
}
