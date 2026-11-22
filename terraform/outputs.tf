output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the load balancer (for Route53 Alias)"
  value       = aws_lb.main.zone_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS Cluster"
  value       = aws_ecs_cluster.main.name
}

output "backend_service_name" {
  description = "Name of the backend ECS service"
  value       = aws_ecs_service.backend.name
}

output "frontend_service_name" {
  description = "Name of the frontend ECS service"
  value       = aws_ecs_service.frontend.name
}

output "backend_ecr_repository_url" {
  description = "ECR repository URL for the backend"
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_repository_url" {
  description = "ECR repository URL for the frontend"
  value       = aws_ecr_repository.frontend.repository_url
}

output "sns_alert_topic_arn" {
  description = "ARN of the SNS topic for CloudWatch alarm notifications"
  value       = aws_sns_topic.alerts.arn
}

output "secrets_manager_secret_arn" {
  description = "ARN of Secrets Manager database URI secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "terraform_state_bucket_name" {
  description = "Name of the S3 bucket storing remote Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_locks_dynamodb_table" {
  description = "Name of the DynamoDB table used for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}
