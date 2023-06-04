resource "azurerm_key_vault" "stamp" {
  name                = "${local.prefix}-${local.location_short}-kv"
  location            = azurerm_resource_group.stamp.location
  resource_group_name = azurerm_resource_group.stamp.name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"

  tags = var.default_tags
}

# Give KV secret permissions to the service principal that runs the Terraform apply itself
resource "azurerm_key_vault_access_policy" "devops_pipeline_all" {
  key_vault_id = azurerm_key_vault.stamp.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get", "List", "Delete", "Purge", "Set", "Backup", "Restore", "Recover"
  ]
}

# Storage ssh private key for vmss in azure key vault
resource "azurerm_key_vault_secret" "vmss_frontend_privatekey" {
  name         = "vmss-frontend-adminuser-privatekey"
  value        = trimspace(tls_private_key.vmss_frontend_private_key.private_key_openssh)
  key_vault_id = azurerm_key_vault.stamp.id

  depends_on = [
    azurerm_key_vault_access_policy.devops_pipeline_all
  ]
}

# Storage ssh private key for vmss in azure key vault
resource "azurerm_key_vault_secret" "vmss_backend_privatekey" {
  name         = "vmss-backend-adminuser-privatekey"
  value        = trimspace(tls_private_key.vmss_backend_private_key.private_key_openssh)
  key_vault_id = azurerm_key_vault.stamp.id

  depends_on = [
    azurerm_key_vault_access_policy.devops_pipeline_all
  ]
}

####################################### DIAGNOSTIC SETTINGS #######################################

# Use this data source to fetch all available log and metrics categories. We then enable all of them
data "azurerm_monitor_diagnostic_categories" "kv" {
  resource_id = azurerm_key_vault.stamp.id
}

resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "kvladiagnostics"
  target_resource_id         = azurerm_key_vault.stamp.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.stamp.id

  dynamic "log" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.kv.log_category_types

    content {
      category = entry.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = 30
      }
    }
  }

  dynamic "metric" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.kv.metrics

    content {
      category = entry.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = 30
      }
    }
  }
}
