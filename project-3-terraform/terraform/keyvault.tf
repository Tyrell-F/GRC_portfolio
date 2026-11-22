data "azurerm_client_config" "current" {}

resource "random_string" "kv_suffix" {
  length  = 6
  upper   = false
  special = false
}

# POAM-13: no public network access. Reached only through the private endpoint.
resource "azurerm_key_vault" "kv" {
  name                          = "kv-grc-tf${random_string.kv_suffix.result}"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = false
  tags                          = var.tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices" # lets the disk encryption set reach the key
  }
}

# The owner can manage keys and secrets (same as Project 2, K03).
resource "azurerm_role_assignment" "kv_admin_owner" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "time_offset" "key_expiry" {
  offset_years = 1
}

resource "time_offset" "secret_expiry" {
  offset_months = 6
}

# Keys and secrets are created through the Azure Resource Manager API
# (control plane), so Terraform never needs a public path to the vault.
resource "azapi_resource" "cmk" {
  type      = "Microsoft.KeyVault/vaults/keys@2023-07-01"
  name      = "cmk-disk-grc"
  parent_id = azurerm_key_vault.kv.id

  body = {
    properties = {
      kty     = "RSA"
      keySize = 3072
      keyOps  = ["wrapKey", "unwrapKey"]
      attributes = {
        enabled = true
        exp     = time_offset.key_expiry.unix
      }
      rotationPolicy = {
        attributes = {
          expiryTime = "P1Y"
        }
        lifetimeActions = [
          {
            action  = { type = "rotate" }
            trigger = { timeAfterCreate = "P11M" }
          },
          {
            action  = { type = "notify" }
            trigger = { timeBeforeExpiry = "P30D" }
          }
        ]
      }
    }
  }

  response_export_values = ["properties.keyUri", "properties.keyUriWithVersion"]
  depends_on             = [azurerm_role_assignment.kv_admin_owner]
}

# Placeholder value only. Never put a real credential here.
resource "azapi_resource" "test_secret" {
  type      = "Microsoft.KeyVault/vaults/secrets@2023-07-01"
  name      = "lab-test-secret"
  parent_id = azurerm_key_vault.kv.id

  body = {
    properties = {
      value       = "not-a-real-password-123"
      contentType = "text/plain"
      attributes = {
        enabled = true
        exp     = time_offset.secret_expiry.unix
      }
    }
  }

  depends_on = [azurerm_role_assignment.kv_admin_owner]
}

# ---- Private endpoint + private DNS (POAM-13) ----
resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv" {
  name                  = "link-vnet-grc-tf"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "kv" {
  name                = "pe-kv-grc"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.pe.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-kv-grc"
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv.id]
  }
}

# ---- Disk encryption set with double encryption (POAM-03, RA-04) ----
resource "azurerm_disk_encryption_set" "des" {
  name                      = "des-grc-tf"
  location                  = azurerm_resource_group.rg.location
  resource_group_name       = azurerm_resource_group.rg.name
  key_vault_key_id          = azapi_resource.cmk.output.properties.keyUri
  encryption_type           = "EncryptionAtRestWithPlatformAndCustomerKeys"
  auto_key_rotation_enabled = true
  tags                      = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "des_crypto" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_disk_encryption_set.des.identity[0].principal_id
}

# Role assignments take a few minutes to apply. Wait before building the disk.
resource "time_sleep" "des_rbac" {
  create_duration = "120s"
  depends_on      = [azurerm_role_assignment.des_crypto]
}

# VM identity can read exactly one secret (AC-6, same test as Project 2).
resource "azurerm_role_assignment" "vm_secret_reader" {
  scope                = azapi_resource.test_secret.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id
}
