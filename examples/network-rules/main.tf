module "simple" {
    source = "../../"

    name = "simple"
    resource_group = "simple-rg"
    containers = ["state"]
    network_rules = {
        bypass = ["None"],
        ip_rules = ["127.0.0.1"],
    }
}