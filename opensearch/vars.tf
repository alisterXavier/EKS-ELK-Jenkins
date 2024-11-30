variable "identity_pool_id" {
  type = string
}
variable "user_pool_id" {
  type = string
}
variable "cognito_for_opensearch_role_arn" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "public_ids" {
  type = list(string)
}
variable "account_id" {
  type = string
}
variable "cognito_role_arn" {
  type = string
}