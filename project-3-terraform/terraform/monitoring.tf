data "azurerm_subscription" "current" {}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-grc-tf"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.1
  tags                = var.tags
}

# Key Vault audit logs (AU-2, AU-12).
resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "kv-to-law"
  target_resource_id         = azurerm_key_vault.kv.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category_group = "audit"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Subscription Activity Log (AU-2, AU-12).
resource "azurerm_monitor_diagnostic_setting" "activity" {
  name                       = "activity-to-law-tf"
  target_resource_id         = data.azurerm_subscription.current.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "Administrative"
  }

  enabled_log {
    category = "Security"
  }

  enabled_log {
    category = "Policy"
  }
}

# ---- Alerts (POAM-16, AU-6, SI-4, IR-4) ----
resource "azurerm_monitor_action_group" "owner" {
  name                = "ag-grc-owner"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "grcowner"
  tags                = var.tags

  email_receiver {
    name          = "owner"
    email_address = var.alert_email
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "secret_denied" {
  name                  = "alert-kv-secret-denied"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  scopes                = [azurerm_log_analytics_workspace.law.id]
  description           = "A Key Vault secret read was denied (HTTP 403)."
  severity              = 2
  evaluation_frequency  = "PT15M"
  window_duration       = "PT15M"
  skip_query_validation = true # the table does not exist until the first log arrives
  tags                  = var.tags

  criteria {
    query                   = <<-KQL
      AzureDiagnostics
      | where ResourceProvider == "MICROSOFT.KEYVAULT"
      | where OperationName == "SecretGet" and ResultSignature == "Forbidden"
    KQL
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"
  }

  action {
    action_groups = [azurerm_monitor_action_group.owner.id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "role_change" {
  name                  = "alert-role-assignment-change"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  scopes                = [azurerm_log_analytics_workspace.law.id]
  description           = "A role assignment (classic or PIM eligible/active) was created or removed in the subscription."
  severity              = 2
  evaluation_frequency  = "PT15M"
  window_duration       = "PT15M"
  skip_query_validation = true
  tags                  = var.tags

  criteria {
    query                   = <<-KQL
      AzureActivity
            | where OperationNameValue has_any ("roleAssignments", "roleAssignmentScheduleRequests", "roleEligibilityScheduleRequests")
          or OperationNameValue contains "role in PIM"
      | where ActivityStatusValue !~ "Failure"
    KQL
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"
  }

  action {
    action_groups = [azurerm_monitor_action_group.owner.id]
  }
}
