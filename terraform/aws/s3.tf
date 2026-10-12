# ---------------------------------------------------------------------------
# CloudTwin — S3 bucket for Terraform remote state.
# Hardened by default: versioning on (recover from bad state), SSE-S3
# encryption at rest, all public access blocked, and force_destroy = false
# so a careless `terraform destroy` cannot wipe state history.
#
# NOTE: this file CREATES the bucket. To actually USE it as the backend,
# uncomment the backend block below, then run `terraform init -migrate-state`.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "state" {
  bucket = "${var.project_name}-tfstate-${var.region}"

  # false on purpose: the bucket (and state history) must never be deleted
  # accidentally. Delete versions manually if you ever retire the project.
  force_destroy = false

  tags = {
    Name = "${var.project_name}-tfstate"
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled" # every state update keeps a recoverable version
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # SSE-S3 — encrypted at rest, no KMS cost
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true # all four: state files are never public
}

# ---------------------------------------------------------------------------
# Example remote-state backend (commented out until the bucket exists):
#
#   terraform {
#     backend "s3" {
#       bucket  = "cloudtwin-tfstate-ap-south-1"
#       key     = "aws/terraform.tfstate"
#       region  = "ap-south-1"
#       encrypt = true
#       # Free Tier path uses no DynamoDB table (state locking via the
#       # backend's native handling); add dynamodb_table here only if you
#       # later provision one.
#     }
#   }
#
# Usage:
#   1. terraform apply            # creates the bucket with local state
#   2. Uncomment the backend block above (fix the bucket name to match)
#   3. terraform init -migrate-state
# ---------------------------------------------------------------------------
