# Cleanup

Tear everything down in an order that avoids orphaned billable resources.
Run these steps in the order listed.

## 1. Kubernetes (if deployed)

```bash
helm uninstall cloudtwin --namespace cloudtwin
kubectl delete namespace cloudtwin   # removes PVCs, services, secrets
```

## 2. Local Docker

```bash
docker compose -f docker/docker-compose.yml down -v   # -v removes the DB volume
docker system prune -f                                # optional: reclaim disk
```

## 3. Empty the registries (before destroying infra)

Terraform cannot destroy a non-empty ECR/ACR repository unless force-delete is
enabled, so clean images first.

```bash
# AWS ECR
for repo in cloudtwin-api cloudtwin-frontend; do
  aws ecr batch-delete-image --repository-name $repo \
    --image-ids imageTag=latest --region <REGION> 2>/dev/null
done

# Azure ACR (if used)
az acr repository delete -n <ACR_NAME> --repository cloudtwin-api --yes
az acr repository delete -n <ACR_NAME> --repository cloudtwin-frontend --yes
```

## 4. Destroy Terraform stacks — Azure FIRST, then AWS

Azure first, because the DR stack is the one most likely to hold the
surprising bill (B1s VM, ACR). Confirm `enable_vm=false` state is applied
before destroying if you ever enabled the VM.

```bash
cd terraform/azure
terraform destroy        # type 'yes' — verify the plan shows 0 billable leftovers

cd ../aws
terraform destroy        # type 'yes'
```

If a destroy fails on a non-empty S3 bucket or ECR repo, empty it manually
(step 3, plus `aws s3 rm s3://<bucket> --recursive`) and re-run.

## 5. Remove local state (optional)

```bash
rm -rf terraform/aws/.terraform terraform/azure/.terraform
# Do NOT delete *.tfstate if you still need an audit trail; archive instead.
```

## Verify No Charges Checklist

- [ ] AWS console → EC2 → Instances: **0 running** (check all regions you touched)
- [ ] AWS console → ECR: repositories deleted or empty
- [ ] AWS console → S3: backup bucket deleted or empty
- [ ] AWS Billing → Bills: current month shows no EC2/EBS/ECR line items
- [ ] Azure portal → Resource groups: `cloudtwin-dr-rg` deleted
- [ ] Azure Cost Management: no spend on the subscription for this project
- [ ] Local: `docker ps` shows no cloudtwin containers; no stray volumes
- [ ] `terraform state list` in both stacks returns nothing (or dirs archived)

> Keep the `terraform destroy` outputs until the next billing cycle closes, so
> any unexpected charge can be traced back to a resource and timestamp.
