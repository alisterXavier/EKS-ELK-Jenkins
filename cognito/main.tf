resource "aws_cognito_user_pool" "user-pool" {
  name = "opensearch_typewriter_thunder_user_pool"
  admin_create_user_config {
    allow_admin_create_user_only = true
  }
  username_configuration {
    case_sensitive = true
  }
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

}
# resource "aws_cognito_user_pool_client" "pool" {
#   name                                 = "Test_Client"
#   user_pool_id                         = aws_cognito_user_pool.user-pool.id
#   generate_secret                      = true
#   callback_urls                        = ["https://google.com"]
#   allowed_oauth_flows                  = ["code"]
#   allowed_oauth_scopes                 = ["openid"]
#   supported_identity_providers         = ["COGNITO"]
#   explicit_auth_flows = [
#     "ALLOW_USER_SRP_AUTH",
#     "ALLOW_CUSTOM_AUTH",
#     "ALLOW_REFRESH_TOKEN_AUTH",
#     "ALLOW_ADMIN_USER_PASSWORD_AUTH"
#   ]
# }
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "opensearch-typewriter-thunder-101-404-10"
  user_pool_id = aws_cognito_user_pool.user-pool.id
}
resource "aws_cognito_user" "Typer" {
  username     = "Typer"
  password     = "@Qwerty1"
  user_pool_id = aws_cognito_user_pool.user-pool.id
}

# resource "aws_cognito_identity_pool" "identity_pool" {
#   identity_pool_name               = "opensearch_typewriter_thunder_identity_pool"
#   allow_unauthenticated_identities = false
#   cognito_identity_providers {
#     client_id               = aws_cognito_user_pool_client.pool.id
#     provider_name           = "cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.user-pool.id}"
#     server_side_token_check = false
#   }
# }
resource "aws_cognito_identity_pool_roles_attachment" "identity_authenticated_policy" {
  identity_pool_id = aws_cognito_identity_pool.identity_pool.id
  roles = {
    "authenticated" = var.cognito_auth_role_arn
  }
}
