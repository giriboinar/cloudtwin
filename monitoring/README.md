# CloudTwin Monitoring

Prometheus + Grafana observability stack for the CloudTwin API (FastAPI backend
exposes metrics at `http://api:8000/metrics` via `prometheus-fastapi-instrumentator`).

## Files

| File | Purpose |
| ---- | ------- |
| `prometheus.yml` | Scrape config: `cloudtwin-api` (`api:8000/metrics`) and `prometheus` itself, 15s interval, loads `alerts.yml`. |
| `alerts.yml` | Alert rules: `APIDown` (critical), `HighErrorRate` (warning), `HighLatency` (warning). |
| `grafana-dashboard.json` | "CloudTwin API" dashboard: request rate, p95 latency, 5xx error rate, API up status. |

## How to view

docker-compose exposes:

- **Prometheus UI:** http://localhost:9090 — check scrape targets under
  *Status → Targets*; query raw metrics in the Graph view; see firing alerts
  under *Alerts*.
- **Grafana:** http://localhost:3000 — log in (default `admin`/`admin`,
  Prometheus data source pointing at `http://prometheus:9090`
  (docker-compose service name `prometheus`, port 9090). Then import
  `grafana-dashboard.json` (*Dashboards → New → Import*).

## Adding node_exporter on the EC2 host

Node-level metrics (CPU, memory, disk) come from the
[node_exporter](https://github.com/prometheus/node_exporter) running on the
EC2 instance that hosts docker-compose:

```bash
# on the EC2 host
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar xvf node_exporter-1.8.2.linux-amd64.tar.gz
sudo mv node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
sudo useradd --no-create-home --shell /bin/false node_exporter || true
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'EOF'
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
curl -s localhost:9100/metrics | head   # sanity check
```

Add this scrape job to `prometheus.yml` (replace `<EC2_HOST_IP>` with the
instance's IP or DNS; inside compose, `host.docker.internal` works on
Docker Desktop, and the host's private IP on Linux):

```yaml
#  - job_name: "node"
#    static_configs:
#      - targets: ["<EC2_HOST_IP>:9100"]
```

Then reload Prometheus (`docker compose kill -s HUP prometheus` or restart the
container).

## Cloud-native complement

Prometheus/Grafana here give a single pane for application metrics, but they
don't replace the managed services of the target clouds:

- **AWS CloudWatch** — the EC2 host, ECS/EKS (if adopted), and ALB metrics
  live here by default; use it for host-level alarms (CPU, disk, target
  health) alongside Prometheus. CloudWatch can also scrape the same
  Prometheus endpoint via AMP (Amazon Managed Service for Prometheus).
- **Azure Monitor** — if the API runs on Azure Container Apps / AKS, pipe
  the same Prometheus metrics to an Azure Monitor workspace and surface
  them in Azure Managed Grafana, keeping the dashboard panels identical.

Keep Prometheus as the source of truth for application SLOs
(`APIDown`, `HighErrorRate`, `HighLatency`) and let CloudWatch / Azure
Monitor handle infrastructure-level alarms — one owner per signal.
