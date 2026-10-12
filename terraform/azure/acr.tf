# ##########################################################################
# COST WARNING: Azure Container Registry, Basic SKU ~$5/month — NOT free.
# This resource is count-controlled by var.enable_acr (default false).
# Do NOT set enable_acr = true unless you explicitly accept the charge.
# ##########################################################################

resource "azurerm_container_registry" "this" {
  count = var.enable_acr ? 1 : 0

  name                = "${replace(var.project_name, "-", "")}acr${var.environment}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = {
    Project     = "CloudTwin"
    Role        = "disaster-recovery"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
