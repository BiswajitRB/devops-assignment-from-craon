# AWS Secrets Manager Secret for storing MongoDB Connection URI
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.app_name}/mongodb-uri"
  description             = "MongoDB Atlas connection URI for Craon backend"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.app_name}-mongodb-uri"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_val" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = "mongodb+srv://${var.db_username}:${var.db_password}@${var.app_name}-cluster.mongodb.net/craon_db?retryWrites=true&w=majority"
}

# SSM Parameter Store as an alternate/readily queryable parameter
resource "aws_ssm_parameter" "db_uri" {
  name        = "/${var.app_name}/database_url"
  description = "Secure MongoDB Connection String"
  type        = "SecureString"
  value       = "mongodb+srv://${var.db_username}:${var.db_password}@${var.app_name}-cluster.mongodb.net/craon_db?retryWrites=true&w=majority"

  tags = {
    Name = "${var.app_name}-db-ssm"
  }
}
