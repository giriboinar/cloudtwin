# ---------------------------------------------------------------------------
# Log Analytics workspace — secondary monitoring plane for CloudTwin.
# COST: free 5 GB/month ingestion on the default Pay-As-You-Go tier.
# Retention is capped at 30 days here to avoid retention charges beyond
# the free allowance.
# ---------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.project_name}-logs-${var.environment}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    Project     = "CloudTwin"
    Role        = "monitoring"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
