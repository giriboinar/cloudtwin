# CloudTwin — Ansible layer

Provisions and deploys to a single Amazon Linux 2023 EC2 instance
(`t3.micro`) created by the project's Terraform layer. Ansible runs from
the operator's machine (or CI) over SSH.

```
ansible/
├── ansible.cfg                  # defaults (inventory path, yaml output, no retry files)
├── inventory/
│   ├── hosts.yml                # [app_servers] group — ALL VALUES ARE PLACEHOLDERS
│   └── group_vars/
│       └── app_servers.yml      # deploy_user, timezone, app dir
├── playbooks/
│   ├── site.yml                 # main entrypoint: imports the three below in order
│   ├── hardening.yml            # dnf update, deploy user, sshd hardening, timezone
│   ├── docker.yml               # docker + compose plugin, service, docker group
│   └── deploy.yml               # copy compose files, docker compose up, health check
└── files/
    ├── docker-compose.yml       # the stack deployed to /opt/cloudtwin
    └── monitoring/
        └── prometheus.yml       # Prometheus scrape config
```

## Prerequisites

- Ansible installed on the control machine: `pip install ansible-core`
  (or the full `ansible` package).
- An EC2 instance reachable over SSH on port 22 as `ec2-user`, with the
  matching private key on your machine.
- Copy paths: `ansible.builtin.copy` `src` entries in the playbooks are
  relative to the `playbooks/` directory and resolve to `../files/...`.

## Before you run

Edit `inventory/hosts.yml` and replace the placeholders:

| Key | Replace with |
| --- | ----------- |
| `ansible_host` | Public IPv4/DNS of the EC2 instance (Terraform output) |
| `ansible_ssh_private_key_file` | Path to your PEM key, `chmod 600` |

Then run a syntax check and a dry run:

```bash
cd ansible
ansible-playbook --syntax-check playbooks/site.yml
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --check
```

Full run:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

Run only one stage (each file is a standalone playbook):

```bash
ansible-playbook -i inventory/hosts.yml playbooks/hardening.yml
ansible-playbook -i inventory/hosts.yml playbooks/docker.yml
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml
```

## What the plays do

1. **hardening.yml** — `dnf update` all packages; creates the `deploy`
   user with passwordless sudo; disables SSH password authentication
   (restarts `sshd` via handler only when the config changed); sets the
   timezone to `Asia/Kolkata`.
2. **docker.yml** — installs `docker` + `docker-compose-plugin` via `dnf`
   (native on Amazon Linux 2023), starts/enables the `docker` service,
   adds `deploy` to the `docker` group.
3. **deploy.yml** — creates `/opt/cloudtwin`, copies
   `files/docker-compose.yml` and `files/monitoring/prometheus.yml`
   from the repo, runs `docker compose pull` and `up -d` as the
   `deploy` user, then waits for `http://localhost:8000/health` to
   return 200 (30 × 10s retries).

All tasks are idempotent — re-running the playbook is safe.

## Notes

- `ansible.cfg` sets `host_key_checking = False` for demo convenience.
  **Pin host keys (`known_hosts`) in production.**
- The `cloudtwin/api:latest` image in `files/docker-compose.yml` is a
  placeholder; point it at the real registry image built from the
  project's application code.
- No real IPs, keys, or credentials are stored anywhere in this tree.
