terraform {
  backend "s3" {
    # TODO: replace placeholders with real values before running terraform init
    bucket         = "<state-bucket-name>"   # S3 bucket for Terraform state (must be pre-created)
    key            = "eks/terraform.tfstate"
    region         = "<aws-region>"          # e.g. us-east-1
    dynamodb_table = "<lock-table-name>"     # DynamoDB table for state locking (must be pre-created)
    encrypt        = true
  }
}
