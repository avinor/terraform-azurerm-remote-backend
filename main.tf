provider "azurerm" {}

locals {
  network_rule_list = [var.network_rules]
}

data "azurerm_resource_group" "state" {
  name = var.resource_group
}

resource "azurerm_storage_account" "state" {
  name                      = var.name
  resource_group_name       = data.azurerm_resource_group.state.name
  location                  = data.azurerm_resource_group.state.location
  account_kind              = "StorageV2"
  account_tier              = "Standard"
  account_replication_type  = "GRS"
  enable_https_traffic_only = true

  dynamic "network_rules" {
    for_each = local.network_rule_list
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
  count                 = length(var.containers)
  name                  = var.containers[count.index]
  resource_group_name   = data.azurerm_resource_group.state.name
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}

resource "azurerm_management_lock" "logs" {
  count      = var.lock
  name       = "resource-group-level"
  scope      = data.azurerm_resource_group.state.id
  lock_level = "CanNotDelete"
  notes      = "Locked by terraform."
}