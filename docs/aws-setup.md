# AWS Setup (Primary — Free Tier)

This guide provisions the AWS primary environment with Terraform. Everything
listed here is intended to fit within the **AWS Free Tier** for a new account.

> Screenshots of the console and of real `terraform` runs are added to this
> document after the infrastructure is first provisioned.

## Prerequisites

- An AWS account (Free Tier eligible ideally).
- AWS CLI v2 installed and `aws configure` completed with an IAM user or
  SSO profile that can create VPC, EC2, ECR, S3, and IAM resources.
- Terraform ≥ 1.5 installed.
- An SSH key pair available locally (`~/.ssh/cloudtwin.pub`) — the public key
  is registered with EC2 for Ansible access later.

```bash
aws sts get-caller-identity   # verify credentials work
terraform -version             # verify Terraform is installed
```

## Step-by-Step

```bash
cd terraform/aws

# 1. Initialize providers and modules
terraform init

# 2. Review the plan — confirm instance type is t3.micro, no NAT gateways,
#    no ALBs, nothing that bills outside the Free Tier
terraform plan -out tfplan

# 3. Apply
terraform apply tfplan
```

## What Gets Created

| Resource | Details | Cost |
|---|---|---|
| VPC | `10.0.0.0/16`, DNS hostnames enabled | Free Tier |
| Public subnet | `10.0.1.0/24` (single AZ) | Free Tier |
| Private subnet | `10.0.2.0/24` (single AZ) | Free Tier |
| Internet Gateway + route tables | Public subnet route to IGW | Free Tier |
| Security group | Inbound 22 (SSH, restricted), 80/443 (HTTP/S), 8000 (API, restricted) | Free Tier |
| EC2 instance | `t3.micro`, Amazon Linux 2023, 30 GB gp3 root volume | Free Tier (750 hrs/mo) |
| ECR repositories | `cloudtwin-api`, `cloudtwin-frontend` | Free Tier (500 MB storage) |
| S3 bucket | `cloudtwin-backups-*` for pg_dump artifacts | Free Tier (5 GB) |
| IAM role + instance profile | Least-privilege: ECR pull, S3 put/get on the backup bucket, CloudWatch agent | Free Tier |
| CloudWatch | Log group `/cloudtwin/app`, basic EC2 monitoring | Free Tier |

> **Deliberately excluded:** NAT Gateway, Application Load Balancer, EKS, and
> multi-AZ RDS — each of these bills outside the Free Tier. The database runs
> as a container on the EC2 host in this path.

## Verifying the EC2 Host

```bash
# From the terraform output
terraform output ec2_public_ip

# SSH in (use your key)
ssh -i ~/.ssh/cloudtwin ec2-user@<EC2_PUBLIC_IP>

# On the host: Docker should be installed and running (Ansible installs it,
# or use the user-data bootstrap — check the variables file)
docker --version
docker compose version
```

Once the host is reachable, continue with the Ansible deployment in
`docs/deployment.md`.
