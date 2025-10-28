# IAM Policy for Terraform State Access
resource "aws_iam_policy" "terraform_state_access" {
  name        = "TerraformStateAccessToDynamodb"
  description = "Policy for accessing Terraform state in S3 and DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketVersioning"
        ]
        Resource = "arn:aws:s3:::tf-statefile-83652954"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::tf-statefile-83652954/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/terraform-state-locks"
      }
    ]
  })

  tags = {
    Name = "TerraformStateAccess"
  }
}

# Attach policy to GitHubActionsRole (existing role)
resource "aws_iam_role_policy_attachment" "github_actions_terraform_state" {
  role       = "GitHubActionsRole"
  policy_arn = aws_iam_policy.terraform_state_access.arn
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
