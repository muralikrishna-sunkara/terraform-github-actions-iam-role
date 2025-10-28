# Terraform AWS Infrastructure with GitHub Actions

This repository contains Terraform code to deploy AWS infrastructure with automated deployment via GitHub Actions using OIDC authentication.

## Infrastructure Components

- **VPC** with DNS support
- **2 Public Subnets** in different availability zones
- **Internet Gateway** and routing
- **EC2 Instance** (t2.micro) with SSM enabled for secure access
- **Security Groups** for EC2
- **IAM Roles and Policies** for SSM access

## Prerequisites

1. AWS Account
2. GitHub Repository
3. AWS CLI installed (for initial setup)

## Setup Instructions

### 1. Configure AWS OIDC Provider for GitHub Actions

First, create an OIDC identity provider in AWS for GitHub Actions:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Create IAM Role for GitHub Actions

Create a file named `trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:*"
        }
      }
    }
  ]
}
```

**Replace:**
- `YOUR_AWS_ACCOUNT_ID` with your AWS account ID
- `YOUR_GITHUB_USERNAME` with your GitHub username
- `YOUR_REPO_NAME` with your repository name

Create the IAM role:

```bash
aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://trust-policy.json
```

### 3. Attach Policies to the Role

Attach necessary permissions for Terraform to manage resources:

```bash
# For EC2, VPC, and related resources
aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

# For IAM role creation
aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
```

**Note:** For production, create a custom policy with minimum required permissions instead of using managed policies.

### 4. Configure GitHub Repository Secret

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `AWS_ROLE_ARN`
5. Value: `arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/GitHubActionsRole`

### 5. (Optional) Configure S3 Backend for State Storage

Uncomment the backend configuration in `main.tf` and create an S3 bucket:

```bash
# Create S3 bucket for state
aws s3 mb s3://your-terraform-state-bucket --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

## Usage

### Local Development

```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply
```

### GitHub Actions Deployment

The workflow automatically triggers on:

- **Pull Requests to main**: Runs `terraform plan` and comments results on the PR
- **Push to main**: Runs `terraform apply` to deploy infrastructure

## Accessing the EC2 Instance

Use AWS Systems Manager Session Manager to connect to the instance (no SSH keys needed):

```bash
# List instances
aws ssm describe-instance-information

# Start session
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx
```

Or use the AWS Console:
1. Go to EC2 Console
2. Select your instance
3. Click **Connect** → **Session Manager** → **Connect**

## Variables

You can customize the deployment by modifying values in `variables.tf` or creating a `terraform.tfvars` file:

```hcl
aws_region            = "us-west-2"
project_name          = "my-custom-project"
vpc_cidr              = "10.0.0.0/16"
public_subnet_1_cidr  = "10.0.1.0/24"
public_subnet_2_cidr  = "10.0.2.0/24"
```

## Security Considerations

1. **No SSH Keys**: The EC2 instance uses SSM for access, eliminating the need for SSH keys
2. **OIDC Authentication**: GitHub Actions uses temporary credentials via OIDC, not static access keys
3. **Least Privilege**: Customize IAM policies to grant minimum required permissions
4. **Security Groups**: Currently allows all outbound traffic; restrict as needed for your use case

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Or manually trigger a destroy via GitHub Actions by modifying the workflow.

## Troubleshooting

### GitHub Actions can't assume role

- Verify the OIDC provider is created in AWS
- Check the trust policy matches your repository
- Ensure the role ARN is correctly set in GitHub secrets

### EC2 instance not showing in SSM

- Wait 5-10 minutes after instance launch
- Verify the IAM role has `AmazonSSMManagedInstanceCore` policy
- Check instance has internet access (required for SSM)

## License

MIT
