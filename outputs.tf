output "vault_id" {
  description = "Vault id for the remote state key vault."
  value       = azurerm_key_vault.state.id
}
