variable "private_subnet_ids" {
  type = list(string)
}
variable "public_subnet_ids" {
  type = list(string)
}
variable "eks_role_arn" {
  type = string
}
variable "pod_execution_role_arn" {
  type = string
}
variable "node_role" {
  type = object({
    arn  = string
    name = string
  })
}
variable "cluster_name" {
  type = string
}
variable "node_group_sg_id" {
  type = string
}
