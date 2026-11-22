# Compliance baseline as code (CA-2, CA-7): the same built-in NIST SP 800-53
# Rev. 5 initiative used in Projects 1 and 2, now scoped to the new group.
resource "azurerm_resource_group_policy_assignment" "nist" {
  name                 = "nist-800-53-r5"
  display_name         = "NIST SP 800-53 Rev. 5 (rg-grc-tf)"
  resource_group_id    = azurerm_resource_group.rg.id
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/179d1daa-458f-4e47-8086-2a68d0d6c38f"
  location             = var.location

  identity {
    type = "SystemAssigned"
  }
}

# Region restriction (Project 1 B03c), now enforced in code.
resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed locations: West US 2 only"
  resource_group_id    = azurerm_resource_group.rg.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"

  parameters = jsonencode({
    listOfAllowedLocations = { value = [var.location] }
  })
}
