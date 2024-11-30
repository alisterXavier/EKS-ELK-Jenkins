data "aws_caller_identity" "current" {}
locals {
  vpc_cidr = "10.0.0.0/20"
  public_subnets = [{
    cidr : "10.0.0.0/26"
    az : "us-east-1a"
    }, {
    cidr : "10.0.0.64/26"
    az : "us-east-1b"
    }, {
    cidr : "10.0.0.128/26"
    az : "us-east-1c"
  }]
  private_subnets = [{
    cidr : "10.0.4.0/22"
    az : "us-east-1a"
    }, {
    cidr : "10.0.8.0/22"
    az : "us-east-1b"
    },
    {
      cidr : "10.0.12.0/22"
      az : "us-east-1c"
  }]
  cluster_name = "thunder"
  account_id   = data.aws_caller_identity.current.account_id
  region = "us-east-1"
}