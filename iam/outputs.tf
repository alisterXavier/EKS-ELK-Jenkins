output "eks_role_arn" {
  value = aws_iam_role.EksRole.arn
}
output "pod_execution_role_arn" {
  value = aws_iam_role.pod_execution_role.arn
}
output "node_role" {
  value = {
    name = aws_iam_role.node_role.name
    arn  = aws_iam_role.node_role.arn
  }
}
output "cognito_auth_role_arn" {
  value = aws_iam_role.authenticated_role.arn
}
output "cognito_for_opensearch_role_arn" {
  value = aws_iam_role.cognito_for_opensearch_role.arn
}
