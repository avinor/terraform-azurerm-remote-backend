module "simple" {
    source = "../../"

    name = "simple"
    resource_group = "simple-rg"
    location = "westeurope"
    backends = ["state"]
    network_rules = {
        bypass = ["None"],
        ip_rules = ["127.0.0.1"],
    }
    user_object_id = "test"
}