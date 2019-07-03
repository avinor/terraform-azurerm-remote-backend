output "vault_ids" {
  description = "Map with vault ids for the different backends."
  value       = zipmap(var.backends, azurerm_key_vault.state.*.id)
}
