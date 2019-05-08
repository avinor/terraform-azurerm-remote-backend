# Remote backend

Terraform module to deploy a remote backend storage for Azure

## Testing

To test that changes are working run validate and plan.

```terraform
terraform init -backend=false examples/simple
terraform validate examples/simple
terraform plan examples/simple
```