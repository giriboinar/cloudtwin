# CloudTwin — Kubernetes Layer

Two ways to deploy the `cloudtwin-api` (FastAPI on port 8000, probes `GET /health` and `GET /ready`):

## Option A: Plain manifests (kubectl / Kustomize)

```
kubectl apply -f kubernetes/manifests/
```

Note: there is no `kustomization.yaml`, so apply the directory directly with `kubectl apply -f` (a Kustomize-based apply with `-k` requires one). If you prefer `-k`, add a minimal `kustomization.yaml` listing the resources.

To update the image and secret for a real deploy:

```
# Real image
kubectl -n cloudtwin set image deployment/cloudtwin-api \
  cloudtwin-api=123456789012.dkr.ecr.ap-south-1.amazonaws.com/cloudtwin-api:v1.0.0

# Real database secret (never put it in the manifest file)
kubectl -n cloudtwin create secret generic cloudtwin-secrets \
  --from-literal=DATABASE_URL='postgresql://user:pass@host:5432/cloudtwin' \
  --dry-run=client -o yaml | kubectl apply -f -
```

The `secret.yaml` in this repo carries only the placeholder `REPLACE_ME` — it is safe to commit, but must be replaced before production use.

## Option B: Helm chart

```
helm install cloudtwin kubernetes/helm/cloudtwin \
  --namespace cloudtwin --create-namespace \
  --set image.repository=123456789012.dkr.ecr.ap-south-1.amazonaws.com/cloudtwin-api \
  --set image.tag=v1.0.0 \
  --set ingress.host=api.yourdomain.com \
  --set env.DATABASE_URL='postgresql://user:pass@host:5432/cloudtwin'
```

Disable optional pieces:

```
--set ingress.enabled=false
--set autoscaling.enabled=false
```

## Local testing (kind / k3s)

```
# kind
kind create cluster --name cloudtwin

# or k3s
curl -sfL https://get.k3s.io | sh -

# deploy (no ingress on kind without a controller — use port-forward)
kubectl apply -f kubernetes/manifests/
kubectl -n cloudtwin port-forward svc/cloudtwin-api 8080:80
curl localhost:8080/health
```

For ingress locally, install the NGINX ingress controller for your cluster
(e.g. the kind/k3s-specific install YAML) and point `cloudtwin.example.com`
at `127.0.0.1` in `/etc/hosts`.

## Layout

```
kubernetes/
├── manifests/            # kubectl apply -f
│   ├── namespace.yaml    # cloudtwin
│   ├── configmap.yaml    # APP_ENV=production, LOG_LEVEL=info
│   ├── secret.yaml       # DATABASE_URL placeholder "REPLACE_ME"
│   ├── deployment.yaml   # 2 replicas, probes, resources, envFrom/secretKeyRef
│   ├── service.yaml      # ClusterIP 80 -> 8000
│   ├── ingress.yaml      # nginx, host placeholder cloudtwin.example.com
│   └── hpa.yaml          # min 2 / max 5, CPU 70%
└── helm/cloudtwin/       # helm install
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
```

Placeholders to replace before production: `<ECR_URL>` (image), `REPLACE_ME` (DATABASE_URL), `cloudtwin.example.com` (ingress host).
