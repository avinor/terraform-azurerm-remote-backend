module "simple" {
    source = "../../"

    name = "simple"
    resource_group = "simple-rg"
    location = "westeurope"
    containers = ["state"]
}