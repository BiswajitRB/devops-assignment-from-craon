# Terraform Remote State Storage: S3 Bucket & DynamoDB Lock Table
# Production Best Practice: Encrypted, Versioned, and Locked State

# 1. S3 Bucket for Storing terraform.tfstate
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "${var.app_name}-terraform-state"
  force_destroy = false

  tags = {
    Name        = "${var.app_name}-terraform-state"
    Description = "Secure S3 remote state backend for Craon Terraform"
  }
}

# 2. Enable Bucket Versioning (Protects against accidental deletion & enables rollback)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 3. Enable Server-Side Encryption by Default (AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 4. Explicitly Block ALL Public Access to the State Bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 5. Lifecycle rule: retain older non-current state versions for 90 days
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "clean_old_state_versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# 6. DynamoDB Table for Distributed State Locking
# Prevents two team members or CI/CD jobs from running 'terraform apply' simultaneously
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.app_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${var.app_name}-terraform-locks"
    Description = "Distributed lock table for Terraform state concurrency"
  }
}
