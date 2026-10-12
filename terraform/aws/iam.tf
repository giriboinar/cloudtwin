# ---------------------------------------------------------------------------
# CloudTwin — IAM role + instance profile for the EC2 Docker host.
# Least privilege: the role can ONLY
#   1. pull images from THIS project's ECR repo,
#   2. publish metrics/logs to THIS project's CloudWatch log group,
#   3. read/write objects in THIS project's Terraform state bucket.
# No administrator access, no wildcard resources beyond what the ECR auth
# API requires (ecr:GetAuthorizationToken must use "*").
# ---------------------------------------------------------------------------

resource "aws_iam_role" "app" {
  name = "${var.project_name}-app-role"

  # Only EC2 instances may assume this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-app-role"
  }
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project_name}-app-profile"
  role = aws_iam_role.app.name

  tags = {
    Name = "${var.project_name}-app-profile"
  }
}

resource "aws_iam_role_policy" "app" {
  name = "${var.project_name}-app-policy"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ECR login: GetAuthorizationToken does not support resource-level
        # permissions, so "*" is required here — and ONLY for this action.
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        # Pull images from this project's ECR repository only.
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        # PutLogEvents/CreateLogStream are scoped to this project's log
        # group only.
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream"
        ]
        Resource = [
          aws_cloudwatch_log_group.app.arn,
          "${aws_cloudwatch_log_group.app.arn}:*"
        ]
      },
      {
        # cloudwatch:PutMetricData does NOT support resource-level
        # permissions, so "*" is required here — but the statement is
        # limited to this single metric action, nothing else.
        Sid      = "CloudWatchMetrics"
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
      },
      {
        # State bucket access: needed if remote-state locking helpers or
        # the app itself must read deployment artifacts from this bucket.
        Sid    = "StateBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.state.arn}/*"
      }
    ]
  })
}
