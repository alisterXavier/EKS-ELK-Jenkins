output "identity_pool_id" {
  value = aws_cognito_identity_pool.identity_pool.id
}
output "user_pool_id" {
  value = aws_cognito_user_pool.user-pool.id
}

output "cognito_domain" {
  value = "${aws_cognito_user_pool_domain.main.domain}.auth.${var.region}.amazoncognito.com"
}