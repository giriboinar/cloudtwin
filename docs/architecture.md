# CloudTwin — Multi-Cloud DevOps Platform: Architecture

## Objectives

CloudTwin is a portfolio-grade, production-style DevOps platform built around a
containerized task-management application. Its goals are:

1. **Realistic application** — a FastAPI backend with a PostgreSQL database and a
   static frontend, representative of a typical modern web service.
2. **Primary cloud: AWS (Free Tier)** — VPC, a single `t3.micro` EC2 host, S3,
   ECR, CloudWatch, and least-privilege IAM.
3. **Secondary cloud / DR: Azure** — VNet, NSG, Storage, ACR, and an *optional*
   B1s VM that is disabled by default to avoid cost.
4. **Full automation surface** — Terraform (IaC), Ansible (configuration
   management), Docker Compose (local), Kubernetes manifests + Helm chart,
   CI/CD pipelines (GitHub Actions primary, Jenkins alternative).
5. **Observability & quality gates** — Prometheus scraping the API's `/metrics`
   endpoint, Grafana dashboards, Trivy image scanning, and optional SonarQube
   static analysis.

The design is deliberately cost-conscious: the AWS primary path runs entirely
within the AWS Free Tier, and the Azure secondary path provisions nothing
billable unless the operator explicitly opts in.

## Components

| Component | Technology | Role |
|---|---|---|
| Frontend | Static files served by nginx | Serves the task-management UI; proxies API calls to the backend |
| API | FastAPI (Python) | REST endpoints for tasks; exposes `/health` and `/metrics` |
| Database | PostgreSQL | Persistent storage for tasks, migrations applied at startup |
| Container registry | AWS ECR / Azure ACR | Versioned images for the API and frontend |
| CI | GitHub Actions (Jenkins alternative) | Build, test, scan, and push images on every push/PR |
| CD / config mgmt | Ansible | Provisions and configures EC2 hosts, deploys Compose stacks |
| IaC | Terraform | Separate `aws/` and `azure/` stacks for cloud infrastructure |
| Orchestration | Kubernetes manifests + Helm chart | Alternative deployment target with scaling and self-healing |
| Monitoring | Prometheus + Grafana | Metrics collection and dashboards |
| Quality | Trivy + optional SonarQube | Image vulnerability scanning, static code analysis |
| Object storage | S3 (AWS) / Storage (Azure) | Backups, Terraform state (optional), static assets |

## Architecture Diagram

```text
                              ┌────────────────────────────────────────────────────┐
                              │                        USER                        │
                              └──────────────────────────┬─────────────────────────┘
                                                         │ HTTPS :80/:443
                     ┌───────────────────────────────────┴───────────────────────────────────┐
                     │                          AWS (PRIMARY — Free Tier)                    │
                     │                                                                       │
                     │   ┌──────────────────────────── VPC ─────────────────────────────┐    │
                     │   │                                                              │    │
                     │   │  ┌────────────── Public Subnet ──────────────┐               │    │
                     │   │  │                                          │               │    │
                     │   │  │   ┌──────────────────────────────┐         │               │    │
                     │   │  │   │        EC2 (t3.micro)        │         │               │    │
                     │   │  │   │                              │         │               │    │
                     │   │  │   │  ┌─────────┐   ┌──────────┐  │         │               │    │
                     │   │  │   │  │  nginx  │──▶│ FastAPI  │──┼──┐      │               │    │
                     │   │  │   │  │ frontend│   │   api    │  │  │      │               │    │
                     │   │  │   │  └─────────┘   └──────────┘  │  │      │               │    │
                     │   │  │   │        │    ┌────────────┐   │  │      │               │    │
                     │   │  │   │        │    │ Prometheus │◀──┘  │      │  (scrapes      │    │
                     │   │  │   │        │    │ + Grafana  │      │      │   /metrics)    │    │
                     │   │  │   │        │    └────────────┘      │      │               │    │
                     │   │  │   └──────────────────────────────┘         │               │    │
                     │   │  │                                          │               │    │
                     │   │  │   ┌────────────── Private Subnet ─────────┐ │              │    │
                     │   │  │   │  ┌──────────────┐                   │ │              │    │
                     │   │  │   │  │  PostgreSQL  │ (container or RDS- │ │              │    │
                     │   │  │   │  │              │  style on host)    │ │              │    │
                     │   │  │   └──────────────┴───────────────────┘ │ │              │    │
                     │   │  └───────────────────────────────────────────┘ │              │    │
                     │   └──────────────────────────────────────────────────────────────┘    │
                     │                                                                       │
                     │   ECR (container images)      S3 (backups, artifacts)                 │
                     │   CloudWatch (logs, metrics, alarms)    IAM (least-privilege roles)   │
                     └───────────────────────────────────────────────────────────────────────┘

   ┌────────────────────────────────── CI ───────────────────────────────────┐
   │  GitHub Actions:  lint → test → Trivy scan → build → push to ECR        │
   │  (Jenkins pipeline provided as an alternative: Jenkinsfile)              │
   └─────────────────────────────────────────────────────────────────────────┘

   ┌────────────────────────────────── CD ───────────────────────────────────┐
   │  Ansible → SSH to EC2 → pull images from ECR → docker compose deploy     │
   │  (Terraform provisions the infra; Ansible configures the host)           │
   └─────────────────────────────────────────────────────────────────────────┘

                     ┌───────────────────────────────────┬───────────────────────────────────┐
                     │        AZURE (SECONDARY / DR)     │   Screenshots are added to this   │
                     │                                   │   document after real runs.       │
                     │   ┌────────────── VNet ───────────┐ │                                   │
                     │   │  Subnet + NSG                 │ │  The Azure path is DISABLED BY    │
                     │   │   • Optional VM (B1s) —       │ │  DEFAULT (enable_vm = false).     │
                     │   │     disabled by default       │ │  Nothing billable is created      │
                     │   │   • Storage (blobs/backups)   │ │  unless the operator opts in.     │
                     │   │   • ACR (mirrored images)     │ │                                   │
                     │   └───────────────────────────────┘ │                                   │
                     └───────────────────────────────────┴───────────────────────────────────┘
```

## Traffic Flow (AWS primary)

1. The user hits the EC2 host over HTTP/HTTPS.
2. nginx (frontend service) serves the static UI and reverse-proxies `/api/*` to
   the FastAPI backend.
3. FastAPI handles CRUD operations against PostgreSQL (connection via SQLAlchemy,
   credentials injected from environment variables).
4. Prometheus scrapes `http://api:8000/metrics`; Grafana visualizes request
   latency, error rates, and DB pool stats.
5. CloudWatch collects host metrics (CPU, memory, disk) and container logs via
   the CloudWatch agent.

## Disaster Recovery Rationale (Azure secondary)

- Images are pushed to **both** ECR and ACR from the same CI pipeline, so a
  container-level restore is a `docker pull` away from either registry.
- Database backups (pg_dump) and application artifacts are replicated to S3,
  with an Azure Storage container as the secondary copy target.
- Terraform `azure/` stack is kept in lockstep with `aws/` so the network and
  registry footprint can be recreated quickly. The B1s VM stays off by default —
  DR is a *cold* standby unless the operator enables it.

## Non-Goals

- No managed Kubernetes in the Free Tier path (EKS control-plane fees defeat the
  purpose); Kubernetes manifests target any standard cluster the operator brings.
- No multi-region active-active on AWS; active-passive with Azure is the DR story.
- No secret management magic in this document — see `SECURITY.md`.
