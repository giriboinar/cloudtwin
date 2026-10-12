# Deployment

Three deployment paths are supported: local Docker Compose, AWS EC2 via
Ansible, and Kubernetes via Helm. Pick the one that matches your target.

## Path 1 — Local (Docker Compose)

Best for development and a first end-to-end smoke test.

```bash
# From the repo root
docker compose -f docker/docker-compose.yml up --build -d

# Verify the API is healthy
curl http://localhost:8000/health
# expected: {"status":"ok"}

# Open the frontend
# http://localhost  (nginx serving the static UI)

# View logs
docker compose -f docker/docker-compose.yml logs -f api

# Tear down (keep volumes) / full reset
docker compose -f docker/docker-compose.yml down
docker compose -f docker/docker-compose.yml down -v   # also removes the DB volume
```

## Path 2 — AWS EC2 (Ansible)

Best for the real Free Tier deployment. Terraform must already have created the
EC2 host (see `docs/aws-setup.md`).

```bash
# 1. Point Ansible at the host — update ansible/inventory.ini with the EC2 IP
#    (or generate it: terraform -chdir=terraform/aws output -raw ec2_public_ip)

# 2. Test SSH connectivity
ansible -i ansible/inventory.ini webservers -m ping

# 3. Run the playbook: installs Docker, logs in to ECR, pulls images,
#    and starts the Compose stack
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml

# 4. Verify from your machine
curl http://<EC2_PUBLIC_IP>/health
# expected: {"status":"ok"}

# 5. Verify on the host
ssh -i ~/.ssh/cloudtwin ec2-user@<EC2_PUBLIC_IP> \
  "docker ps --format 'table {{.Names}}\t{{.Status}}'"
```

## Path 3 — Kubernetes (Helm)

Best for demonstrating orchestration: rolling updates, scaling, self-healing.
Works against any standard cluster (local kind/minikube or a managed cluster
you bring).

```bash
# 1. Point kubectl at your cluster
kubectl cluster-info

# 2. Install the chart
helm install cloudtwin ./kubernetes/helm/cloudtwin \
  --namespace cloudtwin --create-namespace \
  --set image.repository=<REGISTRY>/cloudtwin-api \
  --set image.tag=<TAG>

# 3. Wait for rollout and check pods
kubectl -n cloudtwin rollout status deployment/cloudtwin-api
kubectl -n cloudtwin get pods

# 4. Verify via port-forward (or your Ingress)
kubectl -n cloudtwin port-forward svc/cloudtwin-api 8000:8000 &
curl http://localhost:8000/health
# expected: {"status":"ok"}

# 5. Upgrade example
helm upgrade cloudtwin ./kubernetes/helm/cloudtwin \
  --namespace cloudtwin --set image.tag=<NEW_TAG>

# Uninstall
helm uninstall cloudtwin --namespace cloudtwin
```

## Health Endpoint Reference

| Endpoint | Purpose |
|---|---|
| `GET /health` | Liveness: returns `{"status":"ok"}` when the app is up |
| `GET /metrics` | Prometheus exposition format (request counts, latency, DB pool) |
| `GET /api/tasks` | Application smoke test — should return a JSON list |

If `curl /health` fails on any path, see `docs/troubleshooting.md` before
re-running anything.
