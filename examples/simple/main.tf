module "simple" {
    source = "../../"

    name = "simple"
    resource_group = "simple-rg"
    location = "westeurope"
    backends = ["state"]
    user_object_id = "test"
}