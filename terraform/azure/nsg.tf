# ---------------------------------------------------------------------------
# Network Security Group for the DR subnet.
# - SSH (22): only from var.allowed_ssh_cidr — never leave open to the world.
# - HTTP (80): open to the internet for the DR web endpoint.
# - All other inbound traffic is denied by Azure's default deny-all rule.
# ---------------------------------------------------------------------------

resource "azurerm_network_security_group" "this" {
  name                = "${var.project_name}-nsg-${var.environment}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = {
    Project     = "CloudTwin"
    Role        = "disaster-recovery"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}
