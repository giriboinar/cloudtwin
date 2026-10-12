output "vpc_id" {
  description = "ID of the CloudTwin VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the two public subnets (workloads live here)."
  value       = aws_subnet.public[*].id
}

output "instance_id" {
  description = "ID of the EC2 Docker host instance."
  value       = aws_instance.app.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 Docker host (SSH / app access)."
  value       = aws_instance.app.public_ip
}

output "ecr_repository_url" {
  description = "URL of the ECR repository (docker push target)."
  value       = aws_ecr_repository.app.repository_url
}

output "state_bucket_name" {
  description = "Name of the S3 bucket that holds Terraform remote state."
  value       = aws_s3_bucket.state.id
}
