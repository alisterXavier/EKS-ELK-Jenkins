variable "vpc_cidr" {
  type = string
}

variable "private_subnets" {
  type = list(object({
    cidr : string
    az : string
  }))
}

variable "public_subnets" {
  type = list(object({
    cidr : string
    az : string
  }))
}
variable "cluster_name" {
  type = string
}
