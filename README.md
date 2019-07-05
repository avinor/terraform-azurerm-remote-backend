# Remote backend

Terraform module to deploy a remote backend storage with Key Vault to manage SAS Token and key rotation. To access the remote state the retrieve the SAS Token from Key Vault, do not use the access keys on storage account. SAS Token retrieved from Key Vault grants 1 day access, after that it will have to be refreshed. The access keys on storage account will automatically rotate on a 30 day schedule, this can be adjusted with the input variable `key_rotation_days`.

Each backend creates a new storage account and Key Vault. The Key Vault can also be used for storing other secrets related to terraform.

**Terraform has to run with Owner priviledge in Azure.**

## Usage

Since this will create the remote backend where state should be stored it requires special setup. These examples are based on [tau](https://github.com/avinor/tau).

1. Define tau deployment with backend and all inputs:

```terraform
backend "azurerm" {
    storage_account_name = "tfstatedevsa"
    container_name       = "state"
    key                  = "backend/remotestate.tfstate"
}

environment_variables {
    ARM_SUBSCRIPTION_ID = "******"
}

module {
    source = "avinor/remote-backend/azurerm"
    version = "1.0.0"
}

inputs {
    name = "tfstate"
    resource_group_name = "terraform-rg"
    location = "westeurope"

    backends = ["shared", "dev", "test", "prod"]
}
```

2. Run tau init, plan and apply, but do not create any overrides (skips backend)

```
tau init --no-overrides
tau plan
tau apply
```

3. State should now be stored locally. Reconfigure to backend

```bash
tau init --reconfigure
```

State should now be stored remotely. Any changes after this will use the remote state that have been created with same template. Should now run `tau init` without any extra arguments.

## SAS Token

The SAS Token is stored in Key Vault as a secret with name `{storageaccount_name}-terraformsastoken`. So to access for example below run following command to get in clear text:

```
az keyvault secret show --vault-name tfstatedevkv --name tfstatedevsa-terraformsastoken --query value -o tsv
```

This could also be added as a hook in tau file.

## CI/CD

To use the remote state in a CI/CD process (for instance Azure DevOps Pipelines) it is recommended to create a service principal that is granted access to the Key Vault only. It can then read the SAS Token from Key Vault to access the storage account. CI/CD process should not have access to storage account directly, or use the root access key.

## Notes

### SAS Tokens in Key Vault

SAS Tokens are stored in key-vault to have better control who can access them. Users do not need access to the subscription where storage account is, just the SAS Token to access storage account. SAS Token also allows more granular access control, instead of using root access key to account.