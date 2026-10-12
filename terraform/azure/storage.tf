# ---------------------------------------------------------------------------
# Storage account: holds Terraform state files and DB backups.
# COST: minimal — ~$0.02/GB/month on Standard_LRS hot tier. Backups are
# auto-deleted after var.backup_retention_days by the lifecycle rule below,
# so cost stays near zero.
# ---------------------------------------------------------------------------

resource "random_string" "storage_suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_storage_account" "this" {
  # Storage account names must be globally unique, 3-24 chars, lowercase.
  name                     = "${replace(var.project_name, "-", "")}${var.environment}${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  min_tls_version = "TLS1_2"

  tags = {
    Project     = "CloudTwin"
    Role        = "dr-backups"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Private container — no anonymous access, ever.
resource "azurerm_storage_container" "backups" {
  name                  = "db-backups"
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}

# Delete old backups automatically to keep the storage bill near zero.
resource "azurerm_storage_management_policy" "backups" {
  storage_account_id = azurerm_storage_account.this.id

  rule {
    name    = "delete-old-backups"
    enabled = true

    filters {
      prefix_match = ["db-backups/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.backup_retention_days
      }
    }
  }
}
