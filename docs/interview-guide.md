# Interview Guide

For every major tool or service in CloudTwin: why it was chosen, what problem
it solves, how it integrates with the rest, and which alternatives were
considered and rejected. Written in the Q&A style an interviewer would use.

---

## AWS EC2

**Q: Why EC2, and why a single `t3.micro`?**
A: The goal was a real deployment that stays inside the AWS Free Tier. A single
`t3.micro` (750 hrs/month free) is enough for the API, Postgres, nginx, and the
monitoring sidecars as containers. It keeps the architecture honest — one host,
real SSH access, real Ansible runs — without paying for an ALB or NAT gateway.

**Q: What problem does it solve?**
A: It provides the compute target for the primary environment: somewhere
concrete for Terraform to create, Ansible to configure, and the CI pipeline's
images to land on.

**Q: How does it integrate?**
A: Terraform creates the instance, key pair, security group, and IAM instance
profile. Ansible connects over SSH (using the instance profile for ECR auth),
installs Docker, and deploys the Compose stack. CloudWatch agent ships host and
container logs.

**Q: Alternatives considered?**
A: *ECS Fargate* — simpler orchestration, but the Free Tier doesn't cover it
meaningfully and it hides the host, which weakens the Ansible story. *EKS* —
rejected on cost alone (control-plane fee). *Lambda* — wrong fit for a
long-running Postgres-backed API.

## AWS VPC

**Q: Why a custom VPC instead of the default?**
A: The default VPC is fine for experiments but teaches nothing. A custom VPC
with public/private subnets, an IGW, and explicit route tables demonstrates
real network design and lets the database live in a private subnet, which is
what interviewers expect to see.

**Q: Alternatives?** Default VPC (rejected — no segmentation story) or no VPC
at all (not possible; everything in AWS lives in one).

## AWS S3

**Q: Why S3 here?**
A: Two jobs: durable storage for `pg_dump` backups and an optional remote
backend for Terraform state. It's the cheapest durable storage in the project
and Free Tier covers 5 GB.

**Q: Integration?** A cron/Ansible task dumps Postgres nightly and uploads to
the bucket with versioning enabled. Terraform can optionally store state there.

**Q: Alternatives?** EBS snapshots (tied to the volume, harder to copy
cross-cloud) or pushing backups to Azure Storage directly (done as the
secondary copy — S3 remains primary).

## AWS ECR

**Q: Why ECR over Docker Hub?**
A: Private by default, IAM-integrated (no long-lived Docker Hub tokens in CI),
and 500 MB of storage is Free Tier. `aws ecr get-login-password` gives
short-lived tokens, which is the correct auth pattern.

**Q: Integration?** GitHub Actions builds and pushes tagged images on every
merge to main; Ansible pulls them on the EC2 host using the instance profile —
no credentials stored on the host.

**Q: Alternatives?** Docker Hub (rejected — rate limits, weaker auth story),
self-hosted registry (operational overhead for a portfolio project), ACR-only
(rejected — primary cloud is AWS).

## AWS CloudWatch

**Q: Why CloudWatch instead of shipping everything to Prometheus?**
A: Defense in depth: Prometheus monitors the *application*, CloudWatch monitors
the *host* (CPU, memory, disk, instance status checks) with zero extra
infrastructure. Alarms on status-check failures catch host-level problems
Prometheus can't see.

**Q: Alternatives?** Datadog/New Relic (rejected — paid, overkill), Prometheus
node_exporter only (rejected — no alerting channel without extra work).

## AWS IAM

**Q: What's the IAM design?**
A: Least privilege throughout: the CI role can only push to the two ECR repos;
the EC2 instance profile can only pull from ECR, read/write the backup bucket,
and write CloudWatch logs. No `AdministratorAccess` anywhere, no long-lived
access keys on the host.

**Q: Why does this matter in an interview?**
A: It's the single most common security question. Being able to walk through
each policy and justify every permission shows production thinking.

## Azure VNet / NSG

**Q: Why does a DR cloud need its own network?**
A: DR that shares the primary's network isn't DR. The VNet mirrors the VPC's
segmentation (subnet + NSG rules for 22/80/443) so a failover host lands in an
equivalent, already-understood network.

**Q: Alternatives?** VNet peering to AWS via VPN (rejected — cost and
complexity for a cold standby), no network until failover (rejected — slow,
error-prone under pressure).

## Azure Storage

**Q: Why Azure Storage when S3 exists?**
A: It's the secondary copy target for backups. If AWS has a regional issue,
the restore data is already in the other cloud. Blob storage costs pennies.

## Azure ACR

**Q: Why mirror images to ACR?**
A: Registry availability is part of DR: if ECR is unreachable, the DR host
pulls from ACR. The CI pipeline pushes to both registries from the same build,
so tags stay in sync. ACR Basic (~$5/mo) is the one Azure cost the project
accepts by default; the VM stays off.

## Azure Monitor

**Q: What does Azure Monitor do here?**
A: The equivalent of CloudWatch for the DR side: VM host metrics and
diagnostic logs if the B1s VM is ever enabled. Disabled by default along with
the VM.

## Terraform

**Q: Why Terraform instead of CloudFormation / ARM / click-ops?**
A: One language for both clouds. CloudFormation can't do Azure; ARM/Bicep
can't do AWS. Terraform's plan/apply cycle gives a reviewable diff before
anything changes, and the state file is the inventory Ansible and CI read from.

**Q: Integration?** `terraform/aws` and `terraform/azure` are separate stacks
with matching variable conventions. Outputs (EC2 IP, ECR URLs, ACR name) feed
Ansible inventory and pipeline secrets.

**Q: Alternatives?** Pulumi (rejected — team familiarity and HCL-style
declarative preference; also heavier SDK dependency), CloudFormation + Bicep
(rejected — two languages, no unified workflow).

## Ansible

**Q: Why Ansible when Terraform already exists?**
A: Separation of concerns: Terraform provisions *infrastructure*, Ansible
configures *hosts*. Installing Docker, hardening SSH, deploying the Compose
stack, and rotating credentials are configuration tasks — Terraform is the
wrong tool for them.

**Q: Why agentless?** No agent to install or maintain on the host; SSH +
Python is enough. Idempotent playbooks mean re-runs are safe.

**Q: Alternatives?** Chef/Puppet (rejected — agent overhead), cloud-init only
(rejected — not idempotent, hard to re-run for deploys), manual SSH (rejected —
not repeatable, not reviewable).

## Docker / Docker Compose

**Q: Why containers at all?**
A: Identical artifacts from laptop to EC2 to Kubernetes. The image CI builds
is the image prod runs — that eliminates "works on my machine" as a class of
bug.

**Q: Why Compose locally but Kubernetes as the orchestrator option?**
A: Compose is the fastest faithful local replica (one command, all services).
Kubernetes is the production-grade orchestrator story (self-healing, rolling
updates, scaling). Showing both proves you know which tool fits which context.

**Q: Alternatives?** Podman (fine, but Docker is the industry default and what
interviewers expect), running bare processes (rejected — no artifact parity).

## Kubernetes / Helm

**Q: Why include Kubernetes if the Free Tier path doesn't use it?**
A: Because "can you run this on Kubernetes?" is an interview question, and the
honest answer is "yes — here's the chart." The manifests and Helm chart target
any standard cluster the operator brings; values files parameterize the
registry and tag so the same CI-built images deploy anywhere.

**Q: Why Helm over raw manifests?** Templating and versioned releases:
`helm upgrade --set image.tag=` is the deployment mechanism, with rollback via
`helm rollback`.

**Q: Alternatives?** Kustomize (rejected — Helm's release management fits the
deploy/rollback story better), raw `kubectl apply` (rejected — no versioning).

## GitHub Actions

**Q: Why GitHub Actions as the primary CI?**
A: Zero infrastructure to maintain, native to where the code lives, and the
workflow YAML is reviewable in the repo. The pipeline — lint → test → Trivy
scan → build → push to ECR/ACR — runs on every PR and every merge to main.

**Q: Integration?** Pipeline outputs are the tagged images Ansible and Helm
consume. Trivy failing the build on HIGH/CRITICAL CVEs is the quality gate.

**Q: Alternatives?** Jenkins (provided as the alternative — see below),
GitLab CI (rejected — code lives on GitHub), CircleCI (rejected — external
service, less portable story).

## Jenkins

**Q: Why include Jenkins if GitHub Actions is primary?**
A: Jenkins is still the entrenched CI in many enterprises. The Jenkinsfile
mirrors the GitHub Actions pipeline stage-for-stage, so the project
demonstrates both the modern (Actions) and the traditional (Jenkins)
approaches — and the candidate can discuss migration between them.

**Q: Trade-offs?** Jenkins needs a controller host (cost, maintenance, plugin
management); Actions needs none. Jenkins wins on customization and on-prem
requirements.

## Prometheus

**Q: Why Prometheus?**
A: The pull-based model fits containers perfectly: the API exposes `/metrics`,
Prometheus scrapes it, no agent config on the app side. It's the standard
answer for "how do you monitor this?" and pairs natively with Grafana.

**Q: Integration?** Scrape config targets the API service; alerting rules
(e.g., high error rate, target down) can route to any Alertmanager receiver.

**Q: Alternatives?** StatsD/Graphite (rejected — push model, dated), CloudWatch
custom metrics only (rejected — vendor lock-in, weaker query language than
PromQL).

## Grafana

**Q: Why Grafana with Prometheus?**
A: Prometheus stores and queries; Grafana visualizes. The dashboard shows
request rate, latency percentiles, error rate, and DB pool saturation — the
four signals that answer "is the app healthy?" at a glance.

**Q: Alternatives?** Prometheus's built-in UI (rejected — fine for debugging,
not for dashboards), Kibana (rejected — tied to the Elastic stack).

## SonarQube (optional)

**Q: Why is SonarQube optional?**
A: It needs a persistent server with real memory — overkill to run always for
a portfolio project. When enabled, it gates merges on code smells, bugs, and
coverage thresholds. Optional keeps the default path lean.

**Q: Alternatives?** CodeQL (GitHub-native, narrower language focus),
SonarCloud (rejected — sends code to a third party; self-hosted keeps the
story self-contained).

## Trivy

**Q: Why Trivy for scanning?**
A: Fast, no database server to run, excellent vulnerability DB, and it scans
images *and* IaC (misconfigurations in Terraform). One tool covering both
gates keeps the pipeline simple.

**Q: Integration?** Runs in CI after build, before push; fails the pipeline on
HIGH/CRITICAL. Also runnable locally: `trivy image <img>` and
`trivy config terraform/aws`.

**Q: Alternatives?** Snyk (rejected — account/trial dependency), Clair
(rejected — needs a database, heavier setup).

## PostgreSQL

**Q: Why Postgres instead of MySQL or SQLite?**
A: Postgres is the default serious choice for a relational backend: strict
typing, JSONB when needed, reliable MVCC, and `pg_dump` gives a clean backup
story for the DR replication. SQLite can't serve concurrent writers; MySQL
adds nothing here.

**Q: Integration?** SQLAlchemy in FastAPI; migrations at container startup;
nightly `pg_dump` → S3 → Azure Storage copy.

## nginx

**Q: Why nginx in front of FastAPI?**
A: Separation of concerns: nginx serves static files fast and reverse-proxies
`/api/*` to Uvicorn. In production it would also terminate TLS and handle
rate limiting. One container, standard pattern, interviewers recognize it
instantly.

**Q: Alternatives?** Serving statics from FastAPI (rejected — wastes Python
workers), Traefik/Caddy (fine tools, but nginx is the expected answer and
Caddy's auto-TLS isn't needed for the demo path).
