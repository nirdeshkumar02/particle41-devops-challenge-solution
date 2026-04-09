# Remote S3 backend — stores Terraform state with native locking (no DynamoDB needed).
# See README "Terraform Backend Bootstrap" for one-time bucket creation steps.
#
# ⚠️  ACTION REQUIRED before running terraform init:
# Replace "dev-nird-tf-bucket" below with the unique bucket name you created
# in the README Section 6 "Terraform Backend Bootstrap".
# Alternatively, delete the entire backend "s3" { ... } block to use local state.

terraform {
  backend "s3" {
    bucket       = "dev-nird-tf-bucket"
    key          = "ecs/particle41/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
