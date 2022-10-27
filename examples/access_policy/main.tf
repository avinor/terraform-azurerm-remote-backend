module "simple" {
    source = "../../"

    name = "simple"
    resource_group_name = "simple-rg"
    location = "westeurope"

    access_policies = [
        {
            // Security team, "admin" access
            object_id = "a08fb42d-e046-4100-8fdc-960334618440"
            certificate_permissions = []
            key_permissions = ["Backup", "Create", "Delete", "Get", "Import", "List", "Restore"]
            secret_permissions  = ["Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"]
        },
        {
            // Read only access
            object_id = "a08fb42d-e046-4100-8fdc-960334618440"
            certificate_permissions = []
            key_permissions = ["Sign"]
            secret_permissions = ["Get"]
        }
    ]
}