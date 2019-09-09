module "simple" {
    source = "avinor/remote-backend/azurerm"
    version = "1.0.3"

    name = "simple"
    resource_group_name = "simple-rg"
    location = "westeurope"

    network_rules = {
        bypass = ["None"],
        ip_rules = ["127.0.0.1"],
    }
}