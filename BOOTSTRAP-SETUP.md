# Bootstrap Setup Guide

This guide explains how to set up the Terraform backend and GitHub Actions IAM permissions.

## The Chicken-and-Egg Problem

You have a situation where:
1. Terraform needs S3/DynamoDB access to store state
2. The IAM policy for S3/DynamoDB access is defined in Terraform
3. GitHub Actions needs the IAM policy attached to run Terraform

## Solution: Bootstrap Process

We need to bootstrap the infrastructure in two phases:

### Phase 1: Manual Setup (One-Time)

These resources must be created manually or locally before GitHub Actions can work.

#### Step 1: Create DynamoDB Table

```bash
aws dynamodb create-table \
  --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1
```

#### Step 2: Attach Terraform State Policy to GitHubActionsRole

Create the policy file:

```bash
cat > terraform-state-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketVersioning"
      ],
      "Resource": "arn:aws:s3:::tf-statefile-83652954"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::tf-statefile-83652954/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:DescribeTable"
      ],
      "Resource": "arn:aws:dynamodb:eu-central-1:753968715851:table/terraform-state-locks"
    }
  ]
}
EOF
```

Create and attach the policy:

```bash
# Create the policy
aws iam create-policy \
  --policy-name TerraformStateAccess \
  --policy-document file://terraform-state-policy.json \
  --description "Policy for accessing Terraform state in S3 and DynamoDB"

# Attach to GitHubActionsRole
aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::753968715851:policy/TerraformStateAccess
```

#### Step 3: Verify Attached Policies

```bash
aws iam list-attached-role-policies --role-name GitHubActionsRole
```

You should see:
- `AmazonEC2FullAccess` (or custom EC2 policy)
- `IAMFullAccess` (or custom IAM policy)
- `TerraformStateAccess` (newly added)

### Phase 2: Run Terraform

Now that the backend resources and permissions are in place, you can run Terraform.

#### Option A: Via GitHub Actions (Recommended)

1. Push your code to the `main` branch
2. GitHub Actions will automatically run Terraform
3. The workflow will now have access to the S3 bucket and DynamoDB table

#### Option B: Locally

```bash
# Initialize Terraform
terraform init

# Apply changes
terraform apply
```

---

## What Each File Does

### `iam.tf`
- Creates the IAM policy for Terraform state access
- Attaches the policy to the existing `GitHubActionsRole`
- **Note**: This is for documentation/version control. The policy must be manually created first for the bootstrap.

### `backend-resources.tf`
- Creates the DynamoDB table for state locking via Terraform
- **Note**: The table must be manually created first for the bootstrap.

### Why Bootstrap is Needed

Terraform cannot manage its own backend resources because:
1. Terraform needs the backend (S3 + DynamoDB) to initialize
2. The backend resources are defined in Terraform code
3. Terraform cannot initialize without a working backend

This is why we do the manual setup first, then let Terraform manage everything going forward.

---

## Current Status Check

Verify your setup is complete:

```bash
# 1. Check S3 bucket exists
aws s3 ls s3://tf-statefile-83652954 --region eu-central-1

# 2. Check DynamoDB table exists
aws dynamodb describe-table \
  --table-name terraform-state-locks \
  --region eu-central-1 \
  --query 'Table.TableName'

# 3. Check GitHubActionsRole has correct policies
aws iam list-attached-role-policies \
  --role-name GitHubActionsRole

# 4. Test assuming the role
aws sts get-caller-identity
```

---

## Troubleshooting

### Error: "AccessDenied: User is not authorized to perform: s3:ListBucket"

**Cause**: The `TerraformStateAccess` policy is not attached to `GitHubActionsRole`.

**Solution**: Follow Step 2 in Phase 1 above.

### Error: "ResourceNotFoundException: Cannot do operations on a non-existent table"

**Cause**: The DynamoDB table doesn't exist.

**Solution**: Follow Step 1 in Phase 1 above.

### Error: "NoSuchBucket: The specified bucket does not exist"

**Cause**: The S3 bucket `tf-statefile-83652954` doesn't exist.

**Solution**: Create the bucket:
```bash
aws s3 mb s3://tf-statefile-83652954 --region eu-central-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket tf-statefile-83652954 \
  --versioning-configuration Status=Enabled \
  --region eu-central-1

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket tf-statefile-83652954 \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }' \
  --region eu-central-1
```

---

## After Bootstrap: Managing via Terraform

Once the bootstrap is complete, you can manage some resources via Terraform:

1. **DynamoDB table**: Managed by `backend-resources.tf`
2. **IAM policy**: Managed by `iam.tf`
3. **S3 bucket**: Can be managed if you uncomment the S3 resources in `backend-resources.tf`

**Warning**: If you let Terraform manage the S3 backend bucket, be careful when running `terraform destroy`, as it will try to delete the bucket containing its own state file!

---

## Quick Bootstrap Commands

If you need to run all bootstrap commands in one go:

```bash
# Set variables
export AWS_REGION=eu-central-1
export AWS_ACCOUNT_ID=753968715851
export STATE_BUCKET=tf-statefile-83652954

# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_REGION

# Create and attach policy
cat > /tmp/terraform-state-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetBucketVersioning"],
      "Resource": "arn:aws:s3:::${STATE_BUCKET}"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::${STATE_BUCKET}/*"
    },
    {
      "Effect": "Allow",
      "Action": ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:DescribeTable"],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/terraform-state-locks"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name TerraformStateAccess \
  --policy-document file:///tmp/terraform-state-policy.json

aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/TerraformStateAccess

# Verify
echo "Verifying setup..."
aws s3 ls s3://${STATE_BUCKET} --region $AWS_REGION && echo "✅ S3 bucket exists"
aws dynamodb describe-table --table-name terraform-state-locks --region $AWS_REGION > /dev/null && echo "✅ DynamoDB table exists"
aws iam list-attached-role-policies --role-name GitHubActionsRole | grep TerraformStateAccess && echo "✅ Policy attached"

echo "Bootstrap complete! You can now run Terraform."
```

---

## Summary

1. ✅ S3 bucket already exists: `tf-statefile-83652954`
2. ⏳ Create DynamoDB table: `terraform-state-locks`
3. ⏳ Create IAM policy: `TerraformStateAccess`
4. ⏳ Attach policy to: `GitHubActionsRole`
5. ✅ GitHub Actions workflow is configured correctly
6. ✅ OIDC provider exists and trust policy is correct

After completing steps 2-4, your GitHub Actions workflow will work!
