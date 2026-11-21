# Amazon Elastic Container Registry (ECR) Repositories
resource "aws_ecr_repository" "backend" {
  name                 = "${var.app_name}-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.app_name}-backend-ecr"
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "${var.app_name}-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.app_name}-frontend-ecr"
  }
}

# ECR Lifecycle Policy to keep costs minimal (retain last 10 images)
resource "aws_ecr_lifecycle_policy" "backend_policy" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 untagged or tagged images to control storage costs"
        selection = {
          tagStatus   = "any"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "frontend_policy" {
  repository = aws_ecr_repository.frontend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 untagged or tagged images to control storage costs"
        selection = {
          tagStatus   = "any"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
