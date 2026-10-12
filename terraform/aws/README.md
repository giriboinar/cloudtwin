# CloudTwin — AWS Terraform Layer

Free-Tier-only AWS infrastructure for the **CloudTwin — Multi-Cloud DevOps
Platform** portfolio project. Everything here costs **$0/month** on a new AWS
account within the Free Tier. Nothing in this layer can incur charges: NAT
gateway, ALB, RDS, and Route 53 hosted zones are explicitly excluded (they
appear only as commented-out `PRODUCTION UPGRADE` blocks with cost notes).

## What this provisions

| File | Resources |
|---|---|
| `versions.tf` | Terraform ≥ 1.5, AWS provider `~> 5.0` |
| `variables.tf` | `region` (ap-south-1), `project_name`, `allowed_ssh_cidr`, `instance_type` (t3.micro), `key_name` |
| `main.tf` | VPC `10.0.0.0/16`, 2 public subnets (`10.0.1.0/24`, `10.0.2.0/24`) across 2 AZs, 2 private subnets (`10.0.11.0/24`, `10.0.12.0/24`) **with no NAT route**, internet gateway, public route table + associations |
| `security_groups.tf` | Least-privilege app SG: 80/443 from `0.0.0.0/0`, 8000 from VPC CIDR only, 22 from `allowed_ssh_cidr` only; egress limited to 80/443 + DNS (53) |
| `ec2.tf` | Latest Amazon Linux 2023 AMI, one **t3.micro** in a public subnet; `user_data` installs Docker + the Compose plugin and starts the daemon |
| `iam.tf` | EC2 role + instance profile with an inline least-privilege policy: ECR pull on this project's repo only, CloudWatch logs on this project's log group only, S3 Get/Put on the state bucket only |
| `s3.tf` | Remote-state bucket: versioning on, SSE-S3 encryption, all public access blocked, `force_destroy = false`; commented example `backend "s3"` block |
| `ecr.tf` | Private ECR repo, scan-on-push, immutable tags, AES256, lifecycle policy keeps the last 10 images |
| `cloudwatch.tf` | CPU alarm (> 80% for 2 × 300s periods) + the `/cloudtwin/app` log group (30-day retention) referenced by the IAM policy |
| `outputs.tf` | `vpc_id`, `public_subnet_ids`, `instance_id`, `instance_public_ip`, `ecr_repository_url`, `state_bucket_name` |

## How to init / plan / apply

Prerequisites: Terraform ≥ 1.5, AWS CLI with credentials configured, and an
existing EC2 key pair in `ap-south-1` (pass its name as `key_name`).

```bash
cd ~/workspace/cloudtwin/terraform/aws

terraform init
terraform plan -var="key_name=YOUR_KEY_PAIR_NAME"
terraform apply -var="key_name=YOUR_KEY_PAIR_NAME"
```

Restrict SSH before applying anywhere beyond a personal lab:

```bash
terraform apply \
  -var="key_name=YOUR_KEY_PAIR_NAME" \
  -var="allowed_ssh_cidr=YOUR.IP.ADDR.ESS/32"
```

To switch to remote state later: apply once (creates the bucket), uncomment
the `backend "s3"` example in `s3.tf` (fix the bucket name to match), then run
`terraform init -migrate-state`.

## COST TABLE — proving $0/month on Free Tier

| Resource | Free Tier allowance | This build uses | Monthly cost |
|---|---|---|---|
| EC2 t3.micro (Linux) | 750 hrs/month, 12 months | 1 instance ≈ 730 hrs | **$0** |
| EBS gp3 30 GB | 30 GB-month, 12 months | 30 GB root volume | **$0** |
| S3 Standard | 5 GB storage + 20k GET + 2k PUT /month | State bucket, a few KB | **$0** |
| ECR | 500 MB-month private storage, 12 months | ≤ 10 images, lifecycle-capped | **$0** |
| CloudWatch basic metrics | 10 custom metrics + 10 alarms free-ish; EC2 basic metrics free | 1 alarm, basic EC2 metrics, 30-day logs | **$0** |
| Data transfer out | 100 GB/month (2026 AWS free tier) | Idle host ≈ MBs | **$0** |
| VPC / IGW / subnets / SGs | Always free | 1 VPC, 4 subnets, IGW, route table, 1 SG | **$0** |
| **Total** | | | **$0/month** |

Excluded on purpose (would break $0): NAT gateway (~$32.85/mo + $0.045/GB),
Application Load Balancer (~$16.20/mo + LCU charges), RDS db.t3.micro is Free
Tier eligible but kept out to hold the $0 compute story for this minimal
build, Route 53 hosted zone ($0.50/mo per zone + query charges).

## Production upgrade path (costs money)

1. **NAT gateway** — uncomment the block at the bottom of `main.tf` and give
   the private subnets a NAT route. ≈ **$32.85/month** + $0.045/GB processed.
   Justification: private-subnet workloads with outbound internet.
2. **Application Load Balancer** — place the app behind an ALB in the public
   subnets, move the instance to a private subnet, open the SG to ALB-only
   traffic on 8000. ≈ **$16.20/month** + LCU charges.
   Justification: TLS termination, health checks, multi-instance scaling.
3. **RDS** — add a `db.t3.micro` (PostgreSQL/MySQL, Free Tier eligible for
   12 months) in the private subnets with its own SG allowing 5432/3306 from
   the app SG only. ≈ **$0 for 12 months**, then ~$13–15/month.
   Justification: managed, backed-up relational data instead of containers.
4. **Route 53 hosted zone** — register/delegate a domain and point an alias
   record at the ALB. **$0.50/month** per hosted zone + $0.40/million queries.
   Justification: human-friendly DNS with health-checked failover.
