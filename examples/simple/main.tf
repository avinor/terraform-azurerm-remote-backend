module "simple" {
    source = "avinor/remote-backend/azurerm"
    version = "2.0.0"

    name = "simplestate"
    resource_group_name = "simple-rg"
    location = "westeurope"
}
