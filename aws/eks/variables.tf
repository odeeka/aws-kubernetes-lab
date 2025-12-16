variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "eks_enabled" {
  type    = bool
  default = false
}

variable "cluster_name" {
  type    = string
  default = "eksdemo"
}

variable "rds_username" {
  type    = string
  default = "dbadmin"
}

variable "rds_password" {
  type = string
}

variable "rds_enabled" {
  type    = bool
  default = false
}

