# Example terraform.tfvars
# Copy this file to terraform.tfvars and customize as needed
# Note: terraform.tfvars is excluded from git for security

aws_region            = "eu-central-1"
project_name          = "my-project"
vpc_cidr              = "10.0.0.0/16"
public_subnet_1_cidr  = "10.0.1.0/24"
public_subnet_2_cidr  = "10.0.2.0/24"
