# ---------------------------------------------------------------------------
# CloudTwin — ECR repository for the platform container images.
# Free Tier friendly: 500 MB-month of private repo storage is free, and the
# lifecycle policy caps stored images at the last 10 so usage stays tiny.
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}/app"
  image_tag_mutability = "IMMUTABLE" # a pushed tag can never be overwritten

  # Scan every pushed image for CVEs — free, and surfaces vulnerabilities
  # before the image ever runs on the EC2 host.
  image_scanning_configuration {
    scan_on_push = true
  }

  # AES256 server-side encryption (no KMS key cost).
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-app"
  }
}

# Keep only the 10 most recent images; anything older is expired.
# This keeps the repo well inside the 500 MB/month Free Tier allowance.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the last 10 images, expire the rest"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
