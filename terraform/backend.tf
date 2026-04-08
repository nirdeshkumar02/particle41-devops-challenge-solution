# Remote S3 backend — stores Terraform state with native locking (no DynamoDB needed).
# See README "Terraform Backend Bootstrap" for one-time bucket creation steps.

terraform {
  backend "s3" {
    bucket       = "dev-nird-tf-bucket"
    key          = "ecs/particle41/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
