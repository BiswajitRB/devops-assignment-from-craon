variable "aws_region" {
  type        = string
  description = "AWS region for resources"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. dev, staging, prod)"
  default     = "production"
}

variable "app_name" {
  type        = string
  description = "Application name prefix"
  default     = "craon-app"
}

variable "backend_image" {
  type        = string
  description = "ECR image URI for backend service"
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/craon-backend:latest"
}

variable "frontend_image" {
  type        = string
  description = "ECR image URI for frontend service"
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/craon-frontend:latest"
}

variable "backend_cpu" {
  type        = number
  description = "Fargate CPU units for backend (256 = 0.25 vCPU)"
  default     = 256
}

variable "backend_memory" {
  type        = number
  description = "Fargate memory units for backend (512 = 512 MB)"
  default     = 512
}

variable "backend_desired_count" {
  type        = number
  description = "Number of backend task replicas (requirement: at least two tasks)"
  default     = 2
}

variable "frontend_cpu" {
  type        = number
  description = "Fargate CPU units for frontend"
  default     = 256
}

variable "frontend_memory" {
  type        = number
  description = "Fargate memory units for frontend"
  default     = 512
}

variable "frontend_desired_count" {
  type        = number
  description = "Number of frontend task replicas"
  default     = 2
}

variable "alert_email" {
  type        = string
  description = "Email address for CloudWatch SNS alert notifications"
  default     = "oncall-devops@craon.internal"
}

# MongoDB Atlas configuration (sensitive, keep out of git)
variable "mongodbatlas_public_key" {
  type        = string
  description = "MongoDB Atlas API Public Key"
  default     = "mock-atlas-public-key"
  sensitive   = true
}

variable "mongodbatlas_private_key" {
  type        = string
  description = "MongoDB Atlas API Private Key"
  default     = "mock-atlas-private-key"
  sensitive   = true
}

variable "mongodbatlas_project_id" {
  type        = string
  description = "MongoDB Atlas Project ID"
  default     = "mock-atlas-project-id"
}

variable "db_username" {
  type        = string
  description = "MongoDB database username"
  default     = "craon_app_user"
}

variable "db_password" {
  type        = string
  description = "MongoDB database password"
  default     = "SecureCraonPassw0rd!"
  sensitive   = true
}
