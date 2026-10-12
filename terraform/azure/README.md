# CloudTwin — Azure Terraform Layer

## Purpose

In the CloudTwin architecture **AWS is the primary cloud**. This Azure layer is the
**disaster-recovery (DR) / backup / secondary monitoring** plane:

| Component            | Role in CloudTwin                                    |
| -------------------- | ---------------------------------------------------- |
| Resource group + VNet| Isolated DR network (`10.1.0.0/16`, subnet `10.1.1.0/24`) |
| NSG                  | SSH locked to your IP only, HTTP open, rest denied   |
| Storage account      | Terraform state + DB backups (auto-deleted after 30 days) |
| ACR (Basic)          | Container image mirror for DR failover — **off by default** |
| B1s VM (Ubuntu 22.04)| DR compute node — **off by default**                |
| Log Analytics        | Secondary monitoring plane wired for Azure Monitor   |

> ⚠️ **Azure has NO permanent free tier.** Every paid resource below bills
> from the first second it exists. Read the cost table before you apply.

## Prerequisites

1. Terraform >= 1.5.0 installed.
2. Azure CLI installed and logged in (`az login`), with a subscription set.
3. Sufficient quota in **Central India** (default region).

## Step-by-step apply

```bash
cd ~/workspace/cloudtwin/terraform/azure

# 1. Initialise providers
terraform init

# 2. Review the plan — check that NOTHING paid appears
terraform plan

# 3. Apply the safe baseline (networking + storage + monitoring only)
terraform apply

# 4. If — and only if — you accept the charges, enable paid resources:
terraform apply -var='enable_vm=true'  -var='TF_VAR_admin_password=...'   # ~$8/mo
terraform apply -var='enable_acr=true'                                      # ~$5/mo
```

Pass the VM password via environment variable — **never commit it**:

```bash
export TF_VAR_admin_password='<strong-password>'
```

Destroy everything when done with the DR exercise:

```bash
terraform destroy
```

## Cost table (USD / month, Central India, approximate)

| Resource                              | SKU / tier            | Cost              | Default |
| ------------------------------------- | --------------------- | ----------------- | ------- |
| Resource group                        | —                     | Free              | On      |
| Virtual network                       | —                     | Free              | On      |
| Subnet                                | —                     | Free              | On      |
| Network security group + rules        | —                     | Free              | On      |
| Storage account (Standard_LRS)         | Hot, pay-per-GB       | **~$0.02/GB**     | On      |
| Log Analytics workspace               | PerGB2018, 30-day retention | **Free first 5 GB/mo**, then ~$2.30/GB | On |
| Container Registry                    | Basic                 | **~$5/mo** — NOT free | **Off** (`enable_acr=false`) |
| Linux VM (Standard_B1s, Ubuntu 22.04)  | Burstable, 1 vCPU     | **~$8/mo**        | **Off** (`enable_vm=false`) |
| Public IP (Standard, static)          | created only with VM  | **~$3/mo** when VM enabled | **Off** |

### Free with this baseline
Resource group, VNet, subnet, NSG, and the first 5 GB/month of Log Analytics
ingestion cost **nothing**. The storage account only bills per GB actually
used (backups are deleted after 30 days, so it stays near $0).

### Paid — off by default
- **ACR (Basic): ~$5/month.** Controlled by `enable_acr`. Do not enable for a demo.
- **VM (B1s) + public IP: ~$8–11/month.** Controlled by `enable_vm`.

## ⛔ Do NOT enable the VM unless you accept the charges

`enable_vm` defaults to `false` and the entire VM — NIC, public IP, and the VM
itself — is wrapped in `count = var.enable_vm ? 1 : 0`. Flipping it to `true`
starts billing **immediately** (~$8/month for the VM plus ~$3/month for the
Standard static public IP in Central India). Only enable it with explicit
approval, and run `terraform destroy` (or set it back to `false` and apply)
the moment the DR exercise is over. Restrict `allowed_ssh_cidr` to your own IP
before enabling — the default `0.0.0.0/0` is a placeholder, not a policy.

## File layout

| File          | Contents                                                |
| ------------- | ------------------------------------------------------- |
| `versions.tf` | Terraform + provider pins (`azurerm ~> 3.0`)            |
| `variables.tf`| All inputs; cost switches `enable_vm` / `enable_acr`    |
| `main.tf`     | Resource group, VNet `10.1.0.0/16`, subnet `10.1.1.0/24`|
| `nsg.tf`      | NSG: SSH from your IP, HTTP from internet, rest denied  |
| `storage.tf`  | Storage account (Standard_LRS), private containers, lifecycle rule |
| `acr.tf`      | ACR Basic (admin disabled), **off by default**           |
| `vm.tf`       | B1s Ubuntu 22.04 VM, **off by default**                 |
| `monitor.tf`  | Log Analytics workspace (free 5 GB/mo ingestion)        |
| `outputs.tf`  | IDs, names, and conditional outputs for ACR/VM          |
