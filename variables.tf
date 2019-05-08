variable "name" {
  description = "Name of backend storage account."
}

variable "resource_group" {
  description = "Name of resource group to deploy resources in."
}

variable "containers" {
  description = "List of containers to create in remote backend, could be one container per environment."
  type        = list(string)
}

variable "network_rules" {
  description = "Network rules to apply to storage account."
  type        = object({ bypass = set(string), ip_rules = list(string) })
  default     = null
}

variable "lock" {
  description = "Add a lock on resource group as part of deployment."
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources created."
  type        = map(string)
  default     = {}
}
