# Troubleshooting

Common failures and how to fix them. Each entry lists the **symptom**, the
likely **cause**, and the **fix** with commands.

## 1. `curl /health` → connection refused (local Compose)

**Symptom:** `curl: (7) Failed to connect to localhost port 8000: Connection refused`

**Cause:** The API container hasn't finished starting (migrations/Postgres
readiness), or it crashed on boot.

**Fix:**
```bash
docker compose -f docker/docker-compose.yml ps        # check container state
docker compose -f docker/docker-compose.yml logs api  # read the traceback
# If the DB wasn't ready yet, restart just the API:
docker compose -f docker/docker-compose.yml restart api
```

## 2. `FATAL: password authentication failed` / DB connection refused

**Symptom:** API logs show `could not connect to server` or `password
authentication failed for user`.

**Cause:** `POSTGRES_PASSWORD` (or `DATABASE_URL`) in the Compose environment
doesn't match what Postgres was initialized with, or the API is pointing at
the wrong host.

**Fix:**
```bash
# Confirm both services use the same credentials file/env block
grep -rn POSTGRES_ docker/docker-compose.yml .env 2>/dev/null
# Wipe the stale volume (data loss — dev only) and bring it back up
docker compose -f docker/docker-compose.yml down -v
docker compose -f docker/docker-compose.yml up -d
```

## 3. Port already in use (`bind: address already in use`)

**Symptom:** `Error starting userland proxy: listen tcp4 0.0.0.0:80: bind:
address already in use`

**Cause:** Another process (a previous stack, a local nginx, Apache) owns the
port.

**Fix:**
```bash
sudo ss -ltnp | grep -E ':(80|8000|5432) '   # find the owner
docker compose -f docker/docker-compose.yml down   # if it's our old stack
# Or change the published port in docker-compose.yml and re-run
```

## 4. ECR login / image pull fails (`no basic auth credentials`)

**Symptom:** `docker pull` or the Ansible deploy fails with `no basic auth
credentials` or `denied: requested access to the resource is denied`.

**Cause:** The ECR auth token expired (tokens last 12 hours) or the IAM
principal lacks `ecr:GetAuthorizationToken`.

**Fix:**
```bash
aws ecr get-login-password --region <REGION> | \
  docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com
# Then re-run the pull / playbook. If IAM is the problem, attach the
# AmazonEC2ContainerRegistryReadOnly policy (or the repo's least-privilege role).
```

## 5. Ansible fails: `UNREACHABLE!` / SSH permission denied

**Symptom:** `fatal: [web1]: UNREACHABLE! => {"msg": "Failed to connect to the
host via ssh: Permission denied (publickey)"}`

**Cause:** Wrong key, wrong user (`ec2-user` vs `ubuntu`), or the security
group doesn't allow port 22 from your IP.

**Fix:**
```bash
# 1. Test SSH manually first
ssh -i ~/.ssh/cloudtwin ec2-user@<HOST_IP>
# 2. Confirm the SG allows your IP on 22 (AWS console or):
aws ec2 describe-security-groups --group-ids <SG_ID> --query 'SecurityGroups[0].IpPermissions'
# 3. Confirm ansible.cfg / inventory sets ansible_user and ansible_ssh_private_key_file
ansible -i ansible/inventory.ini webservers -m ping -vvv   # verbose SSH debug
```

## 6. Terraform `Error acquiring the state lock`

**Symptom:** `Error: Error acquiring the state lock ... ConditionalCheckFailedException`

**Cause:** A previous `terraform apply` was interrupted (Ctrl-C, network drop)
and the DynamoDB/S3 lock wasn't released, or a second process is genuinely
running.

**Fix:**
```bash
# First, make sure no other terraform process is actually running
ps aux | grep -i terraform
# If it's a stale lock, release it with the lock ID from the error message
terraform force-unlock <LOCK_ID>
```

## 7. Prometheus shows no targets / `DOWN` state

**Symptom:** Prometheus UI → Status → Targets shows the API job as `DOWN` or
empty.

**Cause:** The scrape config points at the wrong hostname/port, or the API
isn't exposing `/metrics`.

**Fix:**
```bash
# 1. Confirm metrics endpoint responds from the Prometheus host
curl http://<API_HOST>:8000/metrics | head
# 2. Check prometheus.yml scrape_configs job name, targets, and port
grep -A5 scrape_configs monitoring/prometheus/prometheus.yml
# 3. In Compose, both services must share a network so 'api:8000' resolves
docker compose -f docker/docker-compose.yml exec prometheus wget -qO- http://api:8000/metrics | head
```

## 8. Frontend loads but API calls fail (CORS / proxy 502)

**Symptom:** The UI renders, but task lists never load; browser console shows
`Failed to fetch` or `502 Bad Gateway` on `/api/*`.

**Cause:** nginx `proxy_pass` points at the wrong upstream, or the API
container isn't on the same Docker network.

**Fix:**
```bash
# Check nginx upstream config
grep -rn proxy_pass docker/nginx/
# Verify the API is reachable from the nginx container by service name
docker compose -f docker/docker-compose.yml exec frontend wget -qO- http://api:8000/health
# If CORS is the issue instead, confirm the API allows the frontend origin
curl -H "Origin: http://localhost" -I http://localhost:8000/api/tasks
```

## 9. `terraform plan` wants to replace everything

**Symptom:** Every resource shows `-/+ destroy and then create in replacement`.

**Cause:** You switched AWS profiles/regions, changed a force-replacement
argument (like the AMI ID or instance type in a way that forces replacement),
or the state file was lost and re-initialized empty.

**Fix:**
```bash
# Confirm you're using the same backend/state as before
terraform state list | head
# If state was lost, either re-import resources or accept a fresh apply
# followed by cleanup of orphans in the console. Never force-apply blind.
```

## 10. Helm install fails: `ImagePullBackOff`

**Symptom:** Pods stuck in `ImagePullBackOff`.

**Cause:** Wrong registry URL/tag in `--set image.repository`, or the cluster
lacks credentials for a private ECR/ACR.

**Fix:**
```bash
kubectl -n cloudtwin describe pod <POD> | grep -A3 Failed  # exact error
# For private ECR: create an imagePullSecret and reference it
kubectl -n cloudtwin create secret docker-registry ecr-secret \
  --docker-server=<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region <REGION>)
# Then: helm upgrade ... --set imagePullSecrets[0].name=ecr-secret
```
