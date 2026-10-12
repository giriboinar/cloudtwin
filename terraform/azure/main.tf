# ---------------------------------------------------------------------------
# CloudTwin — Azure (DR / secondary monitoring cloud)
# Core networking: resource group, virtual network, subnet.
# ---------------------------------------------------------------------------

provider "azurerm" {
  # Required by the azurerm provider (v3 and v4). Empty block = defaults.
  features {}
}

resource "azurerm_resource_group" "this" {
  name     = "${var.project_name}-azure-${var.environment}"
  location = var.location

  tags = {
    Project     = "CloudTwin"
    Role        = "disaster-recovery"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.project_name}-vnet-${var.environment}"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  tags = {
    Project     = "CloudTwin"
    Role        = "disaster-recovery"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_subnet" "this" {
  name                 = "${var.project_name}-subnet-${var.environment}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.1.1.0/24"]
}
