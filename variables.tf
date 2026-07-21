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

variable "admin_ssh_ip" {
  type        = string
  description = "The explicit public IPv4 address of the local administrator workstation."
}