locals {
  name = replace(var.name, "/[[:^alnum:]]/", "")
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "state" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

resource "azurerm_storage_account" "state" {
  count                     = length(var.backends)
  name                      = format("%s%ssa", lower(local.name, var.backends[count.index]))
  resource_group_name       = azurerm_resource_group.state.name
  location                  = azurerm_resource_group.state.location
  account_kind              = "StorageV2"
  account_tier              = "Standard"
  account_replication_type  = "GRS"
  enable_https_traffic_only = true

  dynamic "network_rules" {
    for_each = var.network_rules == null ? [] : [var.network_rules]
    iterator = nr
    content {
      bypass   = nr.value.bypass
      ip_rules = nr.value.ip_rules
    }
  }

  # TODO Enable soft delete when supported by provider

  tags = var.tags
}

resource "azurerm_storage_container" "state" {
  count                 = length(var.backends)
  name                  = "state"
  resource_group_name   = azurerm_resource_group.state.name
  storage_account_name  = azurerm_storage_account.state[count.index].name
  container_access_type = "private"
}

resource "azurerm_key_vault" "state" {
  count                       = length(var.backends)
  name                        = format("%s-%s-kv", lower(local.name, var.backends[count.index]))
  location                    = azurerm_resource_group.state.location
  resource_group_name         = azurerm_resource_group.state.name
  enabled_for_disk_encryption = true
  enabled_for_deployment      = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id

  sku {
    name = "standard"
  }

  tags = var.tags
}
