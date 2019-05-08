module "simple" {
    source = "../../"

    name = "simple"
    resource_group = "simple-rg"
    containers = ["state"]
}