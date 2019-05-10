provider "azurerm" {}

locals {
  network_rule_list = var.network_rules == null ? [] : [var.network_rules]
}

data "azurerm_client_config" "current" {}

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
  count                 = length(var.backends)
  name                  = var.backends[count.index]
  resource_group_name   = var.resource_group
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}

resource "azurerm_key_vault" "state" {
  count                       = length(var.backends)
  name                        = "tfstate-${var.backends[count.index]}-kv"
  location                    = var.location
  resource_group_name         = var.resource_group
  enabled_for_disk_encryption = true
  enabled_for_deployment      = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id

  sku {
    name = "standard"
  }

  tags = var.tags
}

# TODO Not possible today..
# See https://github.com/terraform-providers/terraform-provider-azurerm/issues/3234
# No way to get object_id of user OR service principal now

# resource "azurerm_key_vault_access_policy" "currentuser" {
#   count                       = length(local.all_backends)
#   vault_name          = "tfstate-${local.all_backends[count.index]}-kv"
#   resource_group_name = var.resource_group

#   tenant_id = data.azurerm_client_config.current.tenant_id
#   object_id = data.azurerm_client_config.current.object_id

#   secret_permissions = [
#     "get",
#     "set",
#     "list",
#   ]
# }

resource "null_resource" "token" {
  count = var.generate_tokens ? length(var.backends) : 0

  provisioner "local-exec" {
    command = "${path.module}/renew-tokens.sh ${data.azurerm_client_config.current.subscription_id} ${azurerm_storage_account.state.name} ${var.backends[count.index]} ${azurerm_key_vault.state[count.index].name} ${var.shared_backend}"
  }
}
