terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.16.1"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source          = "./vpc"
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets
  vpc_cidr        = local.vpc_cidr
  cluster_name    = local.cluster_name
}
module "cognito" {
  source                = "./cognito"
  cognito_auth_role_arn = module.iam.cognito_auth_role_arn
  region                = local.region
}
module "ec2" {
  source            = "./ec2"
  public_subnet_id  = module.vpc.public_subnet_ids[0]
  cognito_domain    = module.cognito.cognito_domain
  opensearch_domain = module.opensearch.opensearch_domain
  vpc_id            = module.vpc.Vpc_Id
}
module "iam" {
  source                 = "./iam"
  oidc_issuer            = module.eks.oidc_issuer
  identity_pool_id       = module.cognito.identity_pool_id
  account_id             = local.account_id
  region                 = local.region
  opensearch_domain_name = module.opensearch.opensearch_domain
}
module "eks" {
  source                 = "./eks"
  private_subnet_ids     = module.vpc.private_subnet_ids
  node_role              = module.iam.node_role
  pod_execution_role_arn = module.iam.pod_execution_role_arn
  eks_role_arn           = module.iam.eks_role_arn
  cluster_name           = local.cluster_name
  public_subnet_ids      = module.vpc.public_subnet_ids
  node_group_sg_id       = module.vpc.node_group_sg_id
}
module "opensearch" {
  source                          = "./opensearch"
  public_ids                      = module.vpc.public_subnet_ids
  identity_pool_id                = module.cognito.identity_pool_id
  user_pool_id                    = module.cognito.user_pool_id
  vpc_id                          = module.vpc.Vpc_Id
  cognito_for_opensearch_role_arn = module.iam.cognito_for_opensearch_role_arn
  account_id                      = local.account_id
  cognito_role_arn                = module.iam.cognito_auth_role_arn
}
module "efs" {
  source            = "./efs"
  public_subnet_ids = module.vpc.public_subnet_ids
  account_id        = local.account_id
  region            = local.region
}


output "Security_groups" {
  value = module.vpc.lb_security_group_id
}
output "Public_Subnets" {
  value = module.vpc.public_subnet_ids
}
output "Vpc_Id" {
  value = module.vpc.Vpc_Id
}
output "cognito_domain" {
  value = module.cognito.cognito_domain
}
output "opensearch_domain" {
  value = module.opensearch.opensearch_domain
}
output "opensearch_proxy_dns" {
  value = module.ec2.opensearch_proxy_dns
}
output "efs_id" {
  value = module.efs.efs_id
}
