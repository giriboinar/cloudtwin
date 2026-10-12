# Security Policy

## No Secrets in the Repository

- **Never commit** AWS access keys, Azure service-principal credentials, SSH
  private keys, database passwords, or any `.env` file containing real values.
  `.gitignore` excludes `.env`, `*.pem`, `*.key`, and Terraform state files.
- Provide an `.env.example` with placeholder values; document every required
  variable in the relevant `docs/` guide.
- Terraform state may contain secrets — use a remote backend (S3 with
  encryption, or Terraform Cloud) rather than committing `*.tfstate`.
- CI secrets (registry credentials, cloud credentials) live in GitHub Actions
  **Secrets** or Jenkins credentials store — never in workflow YAML.

## Least Privilege

- IAM roles follow least privilege: the CI role can only push to the project's
  ECR repositories; the EC2 instance profile can only pull images, access the
  backup S3 bucket, and write CloudWatch logs.
- Security groups / NSGs expose only 22 (restricted to operator IP), 80, and
  443. Port 8000 is not publicly exposed in cloud deployments.
- No `AdministratorAccess`, no long-lived access keys on hosts, no wildcard
  (`*`) resource policies.

## Reporting Vulnerabilities

If you discover a security issue in this project (vulnerable dependency,
exposed credential, misconfigured IaC):

1. **Do not open a public issue.**
2. Email the maintainer directly with a description, affected files, and
   reproduction steps if available.
3. Allow reasonable time for a fix before any public disclosure.

Trivy scans run in CI on every build; findings at HIGH/CRITICAL severity fail
the pipeline until remediated.

## Dependency Hygiene

- Pin base image tags and Python dependencies; review Renovate/Dependabot-style
  updates before merging.
- Re-run `trivy image` and `trivy config` locally after dependency changes.
