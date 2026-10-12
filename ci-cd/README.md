# CloudTwin CI/CD

Two pipeline options are provided — **pick one**:

| Option | Location |
|---|---|
| GitHub Actions | `.github/workflows/ci.yml` (CI) and `.github/workflows/cd.yml` (CD). GitHub only runs workflows from `.github/workflows/`, so those are the real files. Identical copies live under `ci-cd/github-actions/` for reference. |
| Jenkins | `ci-cd/jenkins/Jenkinsfile` — declarative pipeline mirroring the Actions workflows. |

## Pipeline flow

1. **CI** (`ci.yml`, on push + pull request to `main`)
   - `test` — checkout → Python 3.12 → `pip install -r app/backend/requirements.txt` → `pytest app/backend/tests`
   - `sonarqube` — static analysis, **optional** (see below)
   - `build` — `docker build` of the backend image, tagged with the git SHA; the image is saved as a workflow artifact so downstream jobs scan and push the exact same image
   - `trivy` — scans the built image for HIGH/CRITICAL; fails only on CRITICAL
   - `push` — **main branch only**: OIDC-authenticated push to ECR with `:sha` and `:latest` tags
2. **CD** (`cd.yml`, on `workflow_dispatch` or a published Release)
   - SSHes into the EC2 host and runs `cd /opt/cloudtwin && docker compose pull && docker compose up -d`, then verifies with `curl -f http://localhost:8000/health`
   - **Ansible alternative:** replace the SSH step with the idempotent playbook, e.g. `ansible-playbook -i ansible/inventory/prod.ini ansible/playbooks/deploy.yml`

## Required GitHub Secrets

Configure under **Settings → Secrets and variables → Actions**:

| Secret | Required | Purpose |
|---|---|---|
| `AWS_ROLE_ARN` | Yes (CI push) | ARN of the IAM role GitHub assumes via OIDC to push to ECR |
| `ECR_REPOSITORY` | Yes (CI push) | ECR repository name, e.g. `cloudtwin-backend` |
| `EC2_HOST` | Yes (CD) | EC2 public DNS/IP to deploy to |
| `EC2_USER` | Yes (CD) | SSH login user (e.g. `ubuntu`) |
| `EC2_SSH_KEY` | Yes (CD) | Private SSH key for the EC2 host |
| `SONAR_TOKEN` | No (optional) | SonarQube auth token; when absent the SonarQube job is skipped entirely, and when set it still cannot fail the build (`continue-on-error: true`) |

No real secrets, ARNs, or keys are stored anywhere in this repo — workflows reference only `${{ secrets.NAME }}` placeholders.

## How OIDC avoids long-lived keys

The `push` job authenticates to AWS with the `aws-actions/configure-aws-credentials`
action using OpenID Connect instead of static `AWS_ACCESS_KEY_ID` /
`AWS_SECRET_ACCESS_KEY` credentials:

- GitHub mints a short-lived OIDC token for each workflow run (requires the
  job's `permissions: id-token: write`).
- AWS STS exchanges it for temporary credentials by assuming the role in
  `AWS_ROLE_ARN` — valid only if the role's trust policy allows
  `token.actions.githubusercontent.com` for this repo/branch.
- Nothing long-lived is ever stored in GitHub Secrets; there is nothing to
  rotate or leak.

**One-time AWS setup:** create an IAM role (e.g. `github-cloudtwin-ecr-push`)
with an ECR push policy and a trust policy like:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike": { "token.actions.githubusercontent.com:sub": "repo:<ORG>/<REPO>:ref:refs/heads/main" }
    }
  }]
}
```

## Branch protection suggestion

Under **Settings → Branches → Add rule** for `main`:

- ✅ Require a pull request before merging
- ✅ Require status checks to pass before merging — select the `CI` check (or the `Unit tests` / `Vulnerability scan` jobs individually)
- ✅ Require branches to be up to date before merging
- ✅ Restrict who can push to matching branches (CI bots / admins only)
- Optional: require signed commits; enable "Do not allow bypassing the above settings"

This keeps `main` green: every merge must pass tests + the Trivy gate, and only
post-merge pushes to `main` can ship images to ECR.
