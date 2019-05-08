provider "azurerm" {}

locals {
  network_rule_list = var.network_rules == null ? [] : [var.network_rules]
}

resource "azurerm_storage_account" "state" {
  name                      = var.name
  resource_group_name       = var.resource_group
  location                  = var.location
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
  resource_group_name   = var.resource_group
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}
