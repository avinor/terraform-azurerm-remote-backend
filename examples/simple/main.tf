module "simple" {
    source = "avinor/remote-backend/azurerm"
    version = "1.0.1"

    name = "simplestate"
    resource_group_name = "simple-rg"
    location = "westeurope"
}