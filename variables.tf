variable "name" {
  description = "Name of backend storage account."
}

variable "resource_group_name" {
  description = "Name of resource group to deploy resources in."
}

variable "location" {
  description = "Azure location where resources should be deployed."
}

variable "backends" {
  description = "List of backends to create, for instance one per environment."
  type        = list(string)
}

variable "network_rules" {
  description = "Network rules to apply to storage account."
  type        = object({ bypass = set(string), ip_rules = list(string) })
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources created."
  type        = map(string)
  default     = {}
}
