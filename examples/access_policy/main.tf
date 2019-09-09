module "simple" {
    source = "avinor/remote-backend/azurerm"
    version = "1.0.3"

    name = "simple"
    resource_group_name = "simple-rg"
    location = "westeurope"

    access_policies = [
        {
            // Security team, "admin" access
            object_id = "guid"
            certificate_permissions = []
            key_permissions = ["backup", "create", "delete", "get", "import", "list", "restore"]
            secret_permissions  = ["backup", "delete", "get", "list", "purge", "recover", "restore", "set"]
        },
        {
            // Read only access
            object_id = "guid"
            certificate_permissions = []
            key_permissions = ["sign"]
            secret_permissions = ["get"]
        }
    ]
}