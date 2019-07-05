module "simple" {
    source = "../../"

    name = "simple"
    resource_group_name = "simple-rg"
    location = "westeurope"

    backends = ["dev"]

    access_policies = [
        {
            object_id = "guid",
            backends = ["dev"],
            certificate_permissions = [],
            key_permissions = [],
            secret_permissions = ["get"],
        }
    ]
}