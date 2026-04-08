# Remote S3 backend — stores Terraform state and uses native S3 locking (no DynamoDB needed).
#
# ── One-time bootstrap (run BEFORE terraform init) ─────────────────────────────
#
#   aws s3api create-bucket \
#     --bucket <your-bucket-name> \
#     --region us-east-1
#
#   aws s3api put-bucket-versioning \
#     --bucket <your-bucket-name> \
#     --versioning-configuration Status=Enabled
#
#   aws s3api put-bucket-encryption \
#     --bucket <your-bucket-name> \
#     --server-side-encryption-configuration \
#     '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
#
#   Then update the bucket value below and run: terraform init
# ───────────────────────────────────────────────────────────────────────────────

terraform {
  backend "s3" {
    bucket       = "dev-nird-tf-bucket"
    key          = "ecs/particle41/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
