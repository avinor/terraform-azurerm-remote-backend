terraform {
  required_version = ">= 0.12.0"
  required_providers {
    azurerm = ">= 1.31.0"
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

resource "azurerm_resource_group" "state" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

resource "azurerm_storage_account" "state" {
  count                     = length(var.backends)
  name                      = format("%s%ssa", local.name, var.backends[count.index])
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
  name                        = format("%s-%s-kv", local.name, var.backends[count.index])
  location                    = azurerm_resource_group.state.location
  resource_group_name         = azurerm_resource_group.state.name
  enabled_for_disk_encryption = true
  enabled_for_deployment      = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"

  tags = var.tags
}

resource "azurerm_role_assignment" "state" {
  count                = length(var.backends)
  scope                = azurerm_storage_account.state[count.index].id
  role_definition_name = "Storage Account Key Operator Service Role"
  principal_id         = data.azuread_service_principal.key_vault.object_id
}

# Cannot grant access to storage with terraform, do from command line
resource "null_resource" "grant_access" {
  count = length(var.backends)

  provisioner "local-exec" {
    command = "az keyvault set-policy --name ${azurerm_key_vault.state[count.index].name} --upn $(az ad signed-in-user show -o tsv --query userPrincipalName) --storage-permission get list listsas delete set update regeneratekey recover backup restore purge"
  }

  depends_on = ["azurerm_role_assignment.state"]
}

# Setup key rotation from key vault
resource "null_resource" "key_rotation" {
  count = length(var.backends)

  provisioner "local-exec" {
    command = "az keyvault storage add --vault-name ${azurerm_key_vault.state[count.index].name} -n ${azurerm_storage_account.state[count.index].name} --active-key-name key1 --auto-regenerate-key --regeneration-period P${var.key_rotation_days}D --resource-id ${azurerm_storage_account.state[count.index].id}"
  }

  depends_on = ["null_resource.grant_access"]
}