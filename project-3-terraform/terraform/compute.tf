resource "azurerm_network_interface" "vm" {
  name                = "nic-vm-grc-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    # No public IP (AC-17, SC-7).
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  #checkov:skip=CKV_AZURE_50:Extensions are required for trusted launch guest attestation (SI-7) and Azure Policy guest configuration (CM-6). Only Microsoft-published extensions are declared in this code.
  name                            = "vm-grc-01"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.vm.id]
  encryption_at_host_enabled      = true
  secure_boot_enabled             = true
  vtpm_enabled                    = true
  patch_assessment_mode           = "AutomaticByPlatform"
  provision_vm_agent              = true
  allow_extension_operations      = true
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    vnet_cidr = var.vnet_cidr
  }))
  tags = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  # POAM-15: the VM record itself references the disk encryption set.
  os_disk {
    name                   = "osdisk-vm-grc-01"
    caching                = "ReadWrite"
    storage_account_type   = "StandardSSD_LRS"
    disk_encryption_set_id = azurerm_disk_encryption_set.des.id
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {}

  depends_on = [time_sleep.des_rbac]
}

# Trusted launch integrity monitoring (POAM-11, SI-7).
resource "azurerm_virtual_machine_extension" "guest_attestation" {
  name                       = "GuestAttestation"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm.id
  publisher                  = "Microsoft.Azure.Security.LinuxAttestation"
  type                       = "GuestAttestation"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  tags                       = var.tags
}

# Azure Policy guest configuration (POAM-01, CM-6).
resource "azurerm_virtual_machine_extension" "guest_config" {
  name                       = "AzurePolicyforLinux"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm.id
  publisher                  = "Microsoft.GuestConfiguration"
  type                       = "ConfigurationForLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  tags                       = var.tags
}

# Daily auto-shutdown at 11 PM Eastern (cost control, Project 1 E09).
resource "azurerm_dev_test_global_vm_shutdown_schedule" "vm" {
  virtual_machine_id    = azurerm_linux_virtual_machine.vm.id
  location              = azurerm_resource_group.rg.location
  enabled               = true
  daily_recurrence_time = "2300"
  timezone              = "Eastern Standard Time"
  tags                  = var.tags

  notification_settings {
    enabled = false
  }
}
