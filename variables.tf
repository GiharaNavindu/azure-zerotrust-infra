variable "location" {
  type        = string
  description = "The Azure region where resources will be deployed."
  default     = "eastus"
}

variable "environment" {
  type        = string
  description = "Deployment environment name."
  default     = "Dev"
}