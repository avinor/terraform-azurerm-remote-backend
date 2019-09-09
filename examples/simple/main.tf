module "simple" {
    source = "avinor/remote-backend/azurerm"
    version = "1.0.3"

    name = "simplestate"
    resource_group_name = "simple-rg"
    location = "westeurope"
}