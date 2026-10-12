# ##########################################################################
# !!! COSTS ~$8/MONTH — DISABLED BY DEFAULT !!!
#
# The entire resource in this file is wrapped with:
#     count = var.enable_vm ? 1 : 0
#
# Enable ONLY with explicit approval: set enable_vm = true and accept the
# ~$8/month charge for a Standard_B1s VM in Central India. Azure has NO
# permanent free tier — the meter starts the moment this applies.
# ##########################################################################

resource "azurerm_public_ip" "vm" {
  count = var.enable_vm ? 1 : 0

  name                = "${var.project_name}-vm-pip-${var.environment}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Project     = "CloudTwin"
    Role        = "disaster-recovery"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_network_interface" "vm" {
  count = var.enable_vm ? 1 : 0

  name                = "${var.project_name}-vm-nic-${var.environment}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm[0].id
  }

  tags = {
    Project     = "CloudTwin"
    Role        = "disaster-recovery"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  count = var.enable_vm ? 1 : 0

  name                = "${var.project_name}-dr-vm-${var.environment}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  size                = "Standard_B1s" # ~$8/month in Central India — cheapest usable size
  admin_username      = var.admin_username
  admin_password      = var.admin_password # sensitive var, never hardcoded

  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.vm[0].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    Project     = "CloudTwin"
    Role        = "disaster-recovery"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
