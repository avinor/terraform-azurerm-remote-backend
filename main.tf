terraform {
  required_version = ">= 0.12.0"
  required_providers {
    azurerm = ">= 1.31.0"
  }
}

locals {
  name = lower(replace(var.name, "/[[:^alnum:]]/", ""))

  flatten_policies = flatten([for policy in var.access_policies :
    [for backend in policy.backends : {
      policy: policy,
      backend: backend,
    }]
  ])
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
  name                        = format("%s%skv", local.name, var.backends[count.index])
  location                    = azurerm_resource_group.state.location
  resource_group_name         = azurerm_resource_group.state.name
  enabled_for_disk_encryption = true
  enabled_for_deployment      = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"

  tags = var.tags
}

resource "azurerm_key_vault_access_policy" "current" {
  count        = length(var.backends)
  key_vault_id = azurerm_key_vault.state[count.index].id

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
  count        = length(local.flatten_policies)
  key_vault_id = azurerm_key_vault.state[index(var.backends, local.flatten_policies[count.index].backend)].id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = local.flatten_policies[count.index].policy.object_id

  secret_permissions = local.flatten_policies[count.index].policy.secret_permissions
  key_permissions = local.flatten_policies[count.index].policy.key_permissions
  certificate_permissions = local.flatten_policies[count.index].policy.certificate_permissions
}

resource "azurerm_role_assignment" "state" {
  count                = length(var.backends)
  scope                = azurerm_storage_account.state[count.index].id
  role_definition_name = "Storage Account Key Operator Service Role"
  principal_id         = data.azuread_service_principal.key_vault.object_id
}

# Cannot grant access to storage with terraform, do from command line
resource "null_resource" "generate_sas_definition" {
  count = length(var.backends)

  provisioner "local-exec" {
    command = "${path.module}/generate-sas-definition.sh ${data.azurerm_client_config.current.subscription_id} ${azurerm_storage_account.state[count.index].name} ${azurerm_key_vault.state[count.index].name} ${azurerm_storage_account.state[count.index].id} ${var.key_rotation_days}"
  }

  depends_on = ["azurerm_role_assignment.state", "azurerm_key_vault_access_policy.current"]
}
