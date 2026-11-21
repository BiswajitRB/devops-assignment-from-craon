# MongoDB Atlas Database Provisioning with Terraform
# Demonstrates infrastructure-as-code for managed MongoDB (free tier M0)

# Database User with readWrite privileges
resource "mongodbatlas_database_user" "app_user" {
  username           = var.db_username
  password           = var.db_password
  project_id         = var.mongodbatlas_project_id
  auth_database_name = "admin"

  roles {
    role_name     = "readWrite"
    database_name = "craon_db"
  }
}

# Network access list: allows ECS tasks to reach MongoDB Atlas
resource "mongodbatlas_project_ip_access_list" "ecs_access" {
  project_id = var.mongodbatlas_project_id
  cidr_block = "0.0.0.0/0" # In prod, restricted to NAT Gateway Elastic IPs or AWS VPC Peering / PrivateLink
  comment    = "Allow ECS outbound access (VPC Peering/NAT Gateway recommended in enterprise prod)"
}

# Free tier M0 cluster
resource "mongodbatlas_advanced_cluster" "cluster" {
  project_id   = var.mongodbatlas_project_id
  name         = "${var.app_name}-cluster"
  cluster_type = "REPLICA_SET"

  replication_specs {
    region_configs {
      electable_specs {
        instance_size = "M0"
      }
      provider_name         = "TENANT"
      backing_provider_name = "AWS"
      region_name           = "US_EAST_1"
      priority              = 7
    }
  }

  tags {
    key   = "Environment"
    value = var.environment
  }
}
