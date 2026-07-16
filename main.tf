terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100.0"
    }
  }
  required_version = ">= 1.5.0"


  backend "azurerm" {
    resource_group_name  = "rg-tfstate-mgmt"
    storage_account_name = "sttfstatesttfstate84719" 
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Resource Group for Application Infrastructure
resource "azurerm_resource_group" "app_rg" {
  name     = "rg-enterprise-zerotrust-dev"
  location = var.location

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# The Core Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-enterprise-dev"
  location            = azurerm_resource_group.app_rg.location
  resource_group_name = azurerm_resource_group.app_rg.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# 1. Management Subnet (Jumpboxes/Build agents)
resource "azurerm_subnet" "mgmt" {
  name                 = "snet-mgmt"
  resource_group_name  = azurerm_resource_group.app_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# 2. Application Subnet (Backend runtimes)
resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.app_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.10.0/24"]
}

# 3. Database Subnet (Storage/Database runtimes)
resource "azurerm_subnet" "db" {
  name                 = "snet-db"
  resource_group_name  = azurerm_resource_group.app_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.20.0/24"]
}


# Baseline Security Group for Application Subnet
resource "azurerm_network_security_group" "app_nsg" {
  name                = "nsg-snet-app-dev"
  location            = azurerm_resource_group.app_rg.location
  resource_group_name = azurerm_resource_group.app_rg.name

  # Security Principle: Explicitly Block Inter-Subnet Lateral Movement by default
  security_rule {
    name                       = "Deny-Subnet-Lateral-Movement"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "10.0.0.0/16"
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Associate NSG to Subnet
resource "azurerm_subnet_network_security_group_association" "app_assoc" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}