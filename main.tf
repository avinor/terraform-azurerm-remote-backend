terraform {
  required_version = ">= 0.12.0"
  required_providers {
    azurerm = "~> 1.33.0"
  }
}

locals {
  name = lower(replace(var.name, "/[[:^alnum:]]/", ""))
}

data "azurerm_client_config" "current" {}

# Special built-in application that exists in all Azure tenants
data "azuread_service_principal" "key_vault" {
  application_id = "cfa8b339-82a2-471a-a3c9-0fc0be7a4093"
}

# Fetch current user info using the az cli
# Not possible to get the object_id of current user (not service principal) now
# https://github.com/terraform-providers/terraform-provider-azurerm/issues/3234
data "external" "user" {
  program = ["az", "ad", "signed-in-user", "show", "--query", "{displayName: displayName,objectId: objectId,objectType: objectType,upn: upn}"]
}

resource "azurerm_resource_group" "state" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

resource "azurerm_storage_account" "state" {
  name                = format("%ssa", local.name)
  resource_group_name = azurerm_resource_group.state.name
  location            = azurerm_resource_group.state.location

  account_kind              = "StorageV2"
  account_tier              = "Standard"
  account_replication_type  = "GRS"
  enable_https_traffic_only = true
  # TODO Enable soft delete when supported by provider

  enable_advanced_threat_protection = var.enable_advanced_threat_protection

  dynamic "network_rules" {
    for_each = var.network_rules == null ? [] : [var.network_rules]
    iterator = nr
    content {
      default_action = "Deny"
      bypass         = nr.value.bypass
      ip_rules       = nr.value.ip_rules
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "state" {
  name                  = "state"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_key_vault" "state" {
  name                        = format("%skv", local.name)
  location                    = azurerm_resource_group.state.location
  resource_group_name         = azurerm_resource_group.state.name
  enabled_for_disk_encryption = true
  enabled_for_deployment      = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"

  tags = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "state" {
  count                      = var.log_analytics_workspace_id != null ? 1 : 0
  name                       = format("%s-analytics", local.name)
  target_resource_id         = azurerm_key_vault.state.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  log {
    category = "AuditEvent"

    retention_policy {
      enabled = false
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }
}

resource "azurerm_key_vault_access_policy" "current" {
  key_vault_id = azurerm_key_vault.state.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.external.user.result.objectId

  secret_permissions = [
    "get",
  ]

  storage_permissions = [
    "set",
    "setsas",
    "regeneratekey",
  ]
}

resource "azurerm_key_vault_access_policy" "users" {
  count        = length(var.access_policies)
  key_vault_id = azurerm_key_vault.state.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = var.access_policies[count.index].object_id

  secret_permissions      = var.access_policies[count.index].secret_permissions
  key_permissions         = var.access_policies[count.index].key_permissions
  certificate_permissions = var.access_policies[count.index].certificate_permissions
}

resource "azurerm_role_assignment" "state" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Account Key Operator Service Role"
  principal_id         = data.azuread_service_principal.key_vault.object_id
}

# Cannot grant access to storage with terraform, do from command line
resource "null_resource" "generate_sas_definition" {
  provisioner "local-exec" {
    command = "${path.module}/generate-sas-definition.sh ${data.azurerm_client_config.current.subscription_id} ${azurerm_storage_account.state.name} ${azurerm_key_vault.state.name} ${azurerm_storage_account.state.id} ${var.key_rotation_days}"
  }

  depends_on = [azurerm_role_assignment.state, azurerm_key_vault_access_policy.current]
}
