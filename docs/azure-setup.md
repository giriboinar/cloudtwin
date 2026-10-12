# Azure Setup (Secondary / DR)

This guide provisions the Azure secondary environment with Terraform.

> ⚠️ **COST WARNING** — Azure has no always-free VM tier equivalent to AWS's
> `t3.micro`. The B1s VM in this stack costs approximately **$8/month** while it
> exists. For that reason, the VM is **disabled by default**
> (`enable_vm = false`): applying the stack with defaults creates only the
> VNet, NSG, Storage account, and ACR — the VM is *not* created.
>
> Screenshots of the Azure portal and of real `terraform` runs are added to
> this document after the infrastructure is first provisioned.

## Prerequisites

- An Azure subscription with the `Contributor` role (or equivalent).
- Azure CLI installed and signed in (`az login`).
- Terraform ≥ 1.5 installed.
- An SSH public key (`~/.ssh/cloudtwin.pub`).

```bash
az account show --query "{name:name, id:id}" -o table   # verify subscription
terraform -version
```

## Step-by-Step (Default: VM Disabled)

```bash
cd terraform/azure

terraform init

# Default apply — enable_vm defaults to false, so NO VM is created
terraform plan -out tfplan
terraform apply tfplan
```

### What Gets Created (defaults)

| Resource | Details | Cost |
|---|---|---|
| Resource group | `cloudtwin-dr-rg` | $0 |
| VNet | `10.1.0.0/16` + subnet `10.1.1.0/24` | $0 |
| NSG | Inbound 22/80/443 rules (restricted sources) | $0 |
| Storage account | Blob container for backup copies | ~$0.02/GB/mo |
| ACR (Basic) | Mirrored images from CI | ~$5/mo ⚠️ |

> ⚠️ **Note:** ACR Basic itself is ~$5/month. If even that is unwanted, skip the
> Azure stack entirely until DR is needed — the design supports provisioning it
> on demand.

## Enabling the Optional B1s VM (Cold-Standby DR Host)

Only do this when you actually want a running DR host. It bills while it exists.

```bash
# Explicit opt-in — do NOT set this in a shared tfvars file by accident
terraform apply -var="enable_vm=true"
```

| Resource | Details | Cost |
|---|---|---|
| VM | `Standard_B1s`, Ubuntu 22.04, 30 GB disk | ~$8/mo ⚠️ |

To stop the billing, either deallocate the VM or re-apply with
`enable_vm=false` (which destroys the VM) — then run `terraform destroy` on the
whole stack if you want zero ongoing cost. See `docs/cleanup.md`.

## Verifying

```bash
terraform output            # review resource names and IPs
az vm show -g cloudtwin-dr-rg -n cloudtwin-dr-vm -d --query publicIps -o tsv  # if VM enabled
```

The Azure host is configured the same way as the AWS host (Ansible playbook is
cloud-agnostic — point it at the VM's IP). See `docs/deployment.md`.
