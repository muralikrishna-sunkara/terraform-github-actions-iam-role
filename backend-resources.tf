# DynamoDB Table for Terraform State Locking
# NOTE: This table must be created manually BEFORE running Terraform
# because Terraform needs it to initialize the backend.
# See BOOTSTRAP-SETUP.md for instructions.
#
# Commented out to avoid conflicts since the table is created manually:
#
# resource "aws_dynamodb_table" "terraform_state_locks" {
#   name         = "terraform-state-locks"
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key     = "LockID"
#
#   attribute {
#     name = "LockID"
#     type = "S"
#   }
#
#   tags = {
#     Name        = "Terraform State Lock Table"
#     Purpose     = "Terraform state locking"
#     ManagedBy   = "Manual (Bootstrap)"
#   }
# }

# S3 Bucket for Terraform State (if not already created)
# Note: This bucket should already exist (tf-statefile-83652954)
# Uncomment below if you need to create it via Terraform

# resource "aws_s3_bucket" "terraform_state" {
#   bucket = "tf-statefile-83652954"
#
#   tags = {
#     Name      = "Terraform State Bucket"
#     Purpose   = "Terraform state storage"
#     ManagedBy = "Terraform"
#   }
# }
#
# resource "aws_s3_bucket_versioning" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
#
#   versioning_configuration {
#     status = "Enabled"
#   }
# }
#
# resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
#
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }
#
# resource "aws_s3_bucket_public_access_block" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
#
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }
