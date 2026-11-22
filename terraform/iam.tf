# ECS Task Execution Role (used by AWS ECS agent to pull images and fetch secrets)
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.app_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Standard managed policy for pulling ECR images and writing CloudWatch logs
resource "aws_iam_role_policy_attachment" "ecs_execution_standard" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Least-privilege inline policy allowing execution role to read MongoDB secret only
resource "aws_iam_policy" "ecs_secrets_access" {
  name        = "${var.app_name}-secrets-read-policy"
  description = "Allows ECS execution role to retrieve MongoDB credentials from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_secrets" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_secrets_access.arn
}

# ECS Task Role (used by the running container code at runtime)
# Kept separate with minimal permissions (Principle of Least Privilege)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.app_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Optional GitHub Actions OIDC Assumable Role (for Part 4 CD workflow)
resource "aws_iam_openid_connect_provider" "github" {
  count = 0 # Provisioned conditionally or pre-existing in AWS Account
  url   = "https://token.actions.githubusercontent.com"
  client_id_list = [
    "sts.amazonaws.com"
  ]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
