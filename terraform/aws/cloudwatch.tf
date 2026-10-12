# ---------------------------------------------------------------------------
# CloudTwin — CloudWatch log group + CPU alarm for the EC2 Docker host.
# Basic monitoring only (Free Tier): the log group has a 30-day retention so
# logs never accumulate into paid storage, and a single CPU alarm covers the
# host. The IAM policy in iam.tf grants this project's log group to the EC2
# role — that reference is aws_cloudwatch_log_group.app.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/app"
  retention_in_days = 30 # cap retention; old logs expire instead of billing

  tags = {
    Name = "${var.project_name}-app-logs"
  }
}

# Alarm when the Docker host is saturated: CPU > 80% for 2 consecutive
# 5-minute periods (600s total). Uses the default EC2 detailed/basic
# CloudWatch metrics — no paid detailed monitoring enabled.
resource "aws_cloudwatch_metric_alarm" "app_cpu_high" {
  alarm_name          = "${var.project_name}-app-cpu-high"
  alarm_description   = "EC2 Docker host CPU above 80% for 10 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300 # 5-minute periods x 2 = 10 minutes
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "missing" # don't alarm on a stopped instance

  dimensions = {
    InstanceId = aws_instance.app.id
  }

  tags = {
    Name = "${var.project_name}-app-cpu-high"
  }
}
