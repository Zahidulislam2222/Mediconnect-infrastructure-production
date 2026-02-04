resource "aws_cognito_user_pool" "main" {
  name = "mediconnect-users-${var.environment}"

  mfa_configuration = "ON"
  software_token_mfa_configuration {
    enabled = true
  }

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
  }

  auto_verified_attributes = ["email"]

  tags = {
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

resource "aws_cognito_user_pool_client" "client" {
  name         = "mediconnect-client-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = true

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  callback_urls                        = ["https://api.mediconnect.com/callback"] # Placeholder
  logout_urls                          = ["https://api.mediconnect.com/logout"]   # Placeholder
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "mediconnect-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id
}
