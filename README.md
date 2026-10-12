# CloudTwin — Multi-Cloud DevOps Platform

![build](https://img.shields.io/badge/build-passing-brightgreen)
![terraform](https://img.shields.io/badge/terraform-%E2%89%A51.5-623CE4)
![license](https://img.shields.io/badge/license-MIT-blue)

A production-style DevOps platform built around a containerized task-management
application (FastAPI + PostgreSQL + static frontend). **AWS is the primary
cloud and runs entirely on the Free Tier**; **Azure is the secondary / DR
cloud** with costs clearly flagged and the VM disabled by default.

## Objectives

- Ship a realistic containerized app with identical artifacts from laptop to
  cloud to Kubernetes.
- Provision all infrastructure as code (Terraform), configure hosts
  idempotently (Ansible), and deploy through CI/CD (GitHub Actions, with a
  Jenkins alternative).
- Observe everything: Prometheus scrapes the API, Grafana dashboards it,
  CloudWatch watches the host.
- Gate quality: Trivy scans images and IaC in CI; SonarQube available as an
  optional stage.
- Keep it cheap: AWS Free Tier primary, Azure DR with nothing billable unless
  explicitly enabled.

## Real-World Use Cases

- **Multi-cloud disaster recovery** — images mirrored to ECR and ACR, database
  backups replicated S3 → Azure Storage, Terraform stacks kept in lockstep so
  the secondary cloud can be brought up on demand.
- **Portfolio / interview artifact** — every tool choice is documented with
  rationale and rejected alternatives in `docs/interview-guide.md`, so the
  project doubles as a walkthrough of production DevOps decision-making.

## Architecture

```text
                    USER
                     │  :80/:443
        ┌────────────┴────────────┐
        │   AWS (PRIMARY, Free)   │
        │  ┌──── VPC ────┐        │
        │  │ public: EC2 │── nginx → FastAPI → PostgreSQL (private) │
        │  │ ECR │ S3 │ CloudWatch │ IAM (least privilege)          │
        │  └─────────────┘        │
        └────────────┬────────────┘
   CI: GitHub Actions → build/test/scan → push ECR (+ACR mirror)
   CD: Ansible → EC2 → docker compose deploy
   Monitoring: Prometheus scrapes /metrics → Grafana
        ┌────────────┴────────────┐
        │ AZURE (SECONDARY / DR)  │
        │  VNet+NSG, Storage, ACR │
        │  B1s VM ~$8/mo — DISABLED BY DEFAULT (enable_vm=false) │
        └─────────────────────────┘
```

Full diagram and component descriptions: [`docs/architecture.md`](docs/architecture.md).

## Repository Structure

```text
cloudtwin/
├── README.md               # this file
├── LICENSE                 # MIT
├── SECURITY.md             # secret handling, vulnerability reporting
├── .gitignore
├── app/                    # FastAPI backend, static frontend, tests
├── docker/                 # Dockerfiles, docker-compose.yml, nginx config
├── terraform/
│   ├── aws/                # VPC, EC2 (t3.micro), ECR, S3, IAM, CloudWatch
│   └── azure/              # VNet, NSG, Storage, ACR, optional B1s VM
├── ansible/                # inventory, playbook: Docker install + deploy
├── kubernetes/
│   ├── manifests/          # raw K8s manifests
│   └── helm/cloudtwin/     # Helm chart
├── ci-cd/                  # GitHub Actions workflows, Jenkinsfile
├── monitoring/             # Prometheus config/rules, Grafana dashboards
└── docs/
    ├── architecture.md
    ├── aws-setup.md
    ├── azure-setup.md
    ├── deployment.md
    ├── troubleshooting.md
    ├── cleanup.md
    └── interview-guide.md
```

## Quickstart (Local)

```bash
docker compose -f docker/docker-compose.yml up --build -d
curl http://localhost:8000/health   # {"status":"ok"}
# UI: http://localhost
```

Cloud deployments: [`docs/deployment.md`](docs/deployment.md) ·
AWS infra: [`docs/aws-setup.md`](docs/aws-setup.md) ·
Azure infra: [`docs/azure-setup.md`](docs/azure-setup.md)

## Cost Breakdown

| Item | Cloud | Cost |
|---|---|---|
| VPC, subnets, IGW, security groups | AWS | $0 (Free Tier) |
| EC2 `t3.micro` + 30 GB gp3 | AWS | $0 (750 hrs/mo Free Tier) |
| ECR (2 repos, ≤500 MB) | AWS | $0 (Free Tier) |
| S3 backups (≤5 GB) | AWS | $0 (Free Tier) |
| CloudWatch basic + log group | AWS | $0 (Free Tier) |
| VNet, NSG | Azure | $0 |
| Storage account (blobs) | Azure | ~$0.02/GB/mo ⚠️ |
| ACR Basic | Azure | ~$5/mo ⚠️ |
| B1s VM (optional, **disabled by default**) | Azure | ~$8/mo while it exists ⚠️ |

⚠️ = paid items — flagged explicitly in `docs/azure-setup.md` and
`docs/cleanup.md`. Destroy instructions: [`docs/cleanup.md`](docs/cleanup.md).

## Author

**RAJASEKHAR Giriboina** — DevOps Engineer
