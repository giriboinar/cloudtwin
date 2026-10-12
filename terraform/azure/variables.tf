variable "project_name" {
  description = "Project name used as a prefix for all Azure resource names."
  type        = string
  default     = "cloudtwin"
}

variable "location" {
  description = "Azure region for all resources. Central India is close to the user and low-cost."
  type        = string
  default     = "Central India"
}

variable "environment" {
  description = "Environment tag (dev/stage/prod). Azure is the DR/secondary cloud for CloudTwin."
  type        = string
  default     = "dev"
}

# ---------------------------------------------------------------------------
# COST CONTROL SWITCHES
# Azure has NO permanent free tier. Every resource below the free Log
# Analytics ingestion allowance costs real money. Keep the switches below at
# their defaults unless you explicitly accept the charges.
# ---------------------------------------------------------------------------

variable "enable_vm" {
  description = "B1s VM costs ~$8/month — keep false unless you accept the charge"
  type        = bool
  default     = false
}

variable "enable_acr" {
  description = "Azure Container Registry (Basic SKU) costs ~$5/month — keep false unless you accept the charge"
  type        = bool
  default     = false
}

variable "allowed_ssh_cidr" {
  description = "WARNING: source CIDR allowed to reach the DR VM over SSH (port 22). Restrict this to your own IP (e.g. 203.0.113.10/32) — 0.0.0.0/0 exposes the VM to the entire internet."
  type        = string
  default     = "0.0.0.0/0"
}

variable "admin_username" {
  description = "Admin username for the DR VM (only used when var.enable_vm = true)."
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Admin password for the DR VM. No default — supply via TF_VAR_admin_password or a tfvars file. Never hardcode."
  type        = string
  sensitive   = true
  default     = ""
}

variable "backup_retention_days" {
  description = "Number of days to retain DB backups in the storage container before the lifecycle rule deletes them."
  type        = number
  default     = 30
}
