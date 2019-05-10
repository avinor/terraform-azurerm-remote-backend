# Remote backend

Terraform module to deploy a remote backend storage with key-vault to store access keys. To access the remote state the SAS Token that is stored in key vault should be used. It will create an automation account that rotates the key every day. This ensures that nobody needs the root access key to access storage account and each backend has it's own key-vault with SAS Token scoped to only that backends container.

Terraform has to run with Owner priviledge in Azure.

## Usage

Since this will create the remote backend where state should be stored it requires special setup. Remote state does not exist first time running so first use module without declaring a remote state:

```terraform
provider "azurerm" {}

module "backend" {
    source  = "avinor/remote-backend/azurerm"
    version = "0.1.0"

    name           = "remotebackendsa"
    resource_group = "terraform-rg"
    location       = "westeurope"

    backends = [
        "shared",
        "dev",
        "test",
        "prod",
    ]

    tags = {
        whatever = "remote-state"
    }
}
```

Run terraform script without any backend

```bash
terraform init -backend=false
terraform apply
```

Once this is done the remote backend should be created and state is stored locally. To upload it to the remote state that has just been created reconfigure terraform.

Create a `terraform.tf` file in same folder

```terraform
terraform {
    backend "azurerm" {
        storage_account_name = "remotebackendsa"
        container_name       = "boot"
        key                  = "bootstrap.terraform.tfstate"
    }
}
```

If required configure an access key for storing state (`ARM_ACCESS_KEY` environment variable for instance). Reconfigure terraform:

```bash
terraform init -reconfigure
```

State should now be stored remotely. Any changes after this will use the remote state that have been created with same template.

## CI/CD

To use the remote state in a CI/CD process (for instance Azure DevOps Pipelines) it is recommended to create a service principal that is granted access to the key-vault only. It can then read the SAS Token from key-vault to access the storage account. CI/CD process should not have access to storage account directly, or use the root access key.

## Notes

### SAS Tokens in key-vault

SAS Tokens are stored in key-vault to have better control who can access them. Users do not need access to the subscription where storage account is, just the SAS Token to access storage account. SAS Token also allows more granular access control, instead of using root access key to account. For instance can prod subscription have read access to shared remote state, but no access to write to it.

### Token expiry date

Looked into using Azure Automation to rotate the keys in key-vault automatically. Maybe this will be implemented later. Keys could be rotated daily together with storage account root access key. Just need to adjust the expiry date in `renew-tokens.sh` and run it on a schedule.