# ---------------------------------------------------------------------------
# CloudTwin — AWS layer input variables
# HARD RULE: everything here must stay inside the AWS Free Tier.
# ---------------------------------------------------------------------------

variable "region" {
  description = "AWS region where all CloudTwin resources are provisioned."
  type        = string
  default     = "ap-south-1" # Mumbai — low latency for the project owner
}

variable "project_name" {
  description = "Project name used as a prefix for every resource name and tag."
  type        = string
  default     = "cloudtwin"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH (port 22) into the EC2 instance."
  type        = string
  # WARNING: 0.0.0.0/0 allows SSH from anywhere on the internet.
  # Restrict this to your own IP (e.g. "203.0.113.5/32") before applying
  # anywhere beyond a personal lab.
  default = "0.0.0.0/0"
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro is Free Tier eligible (750 hrs/month)."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair in var.region, used for SSH access to the instance."
  type        = string
  # No default on purpose: the key pair must already exist in your account.
}
