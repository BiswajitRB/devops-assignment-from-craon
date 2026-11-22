# Explicitly using AWS Default VPC and Subnets as required by the assignment
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC (Used for Craon Assignment)"
  }
}

resource "aws_default_subnet" "default_az1" {
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "Default Subnet AZ 1"
  }
}

resource "aws_default_subnet" "default_az2" {
  availability_zone = "${var.aws_region}b"
  tags = {
    Name = "Default Subnet AZ 2"
  }
}

# 1. ALB Security Group - Public ingress for web traffic
resource "aws_security_group" "alb" {
  name        = "${var.app_name}-alb-sg"
  description = "Public access to Application Load Balancer"
  vpc_id      = aws_default_vpc.default.id

  # Ingress HTTP from anywhere
  ingress {
    description = "Allow inbound HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress HTTPS from anywhere
  ingress {
    description = "Allow inbound HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress to backend and frontend tasks
  egress {
    description = "Allow outbound to anywhere"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-alb-sg"
  }
}

# 2. Frontend ECS Tasks Security Group - Ingress only from ALB on port 8080
resource "aws_security_group" "frontend_tasks" {
  name        = "${var.app_name}-frontend-task-sg"
  description = "Security group for Frontend Fargate tasks"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    description     = "Allow traffic from ALB on non-root port 8080"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow outbound for package/DNS updates"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-frontend-task-sg"
  }
}

# 3. Backend ECS Tasks Security Group - Ingress only from ALB on port 8000
resource "aws_security_group" "backend_tasks" {
  name        = "${var.app_name}-backend-task-sg"
  description = "Security group for Backend Fargate tasks"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    description     = "Allow traffic from ALB on port 8000"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow outbound to internet and MongoDB Atlas"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-backend-task-sg"
  }
}
