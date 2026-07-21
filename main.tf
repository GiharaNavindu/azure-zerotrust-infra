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

# 1. Management Subnet Network Security Group
resource "azurerm_network_security_group" "mgmt_nsg" {
  name                = "nsg-snet-mgmt-dev"
  location            = azurerm_resource_group.app_rg.location
  resource_group_name = azurerm_resource_group.app_rg.name

  # Security Principle: Strict Least-Privilege Inbound Filter
  security_rule {
    name                       = "Allow-SSH-From-Admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_ssh_ip 
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Associate Management NSG to snet-mgmt Subnet
resource "azurerm_subnet_network_security_group_association" "mgmt_assoc" {
  subnet_id                 = azurerm_subnet.mgmt.id
  network_security_group_id = azurerm_network_security_group.mgmt_nsg.id
}

# 2. Public IP for the Jumpbox
resource "azurerm_public_ip" "jumpbox_pip" {
  name                = "pip-vm-jumpbox-dev"
  location            = azurerm_resource_group.app_rg.location
  resource_group_name = azurerm_resource_group.app_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# 3. Network Interface Card for the Jumpbox VM
resource "azurerm_network_interface" "jumpbox_nic" {
  name                = "nic-vm-jumpbox-dev"
  location            = azurerm_resource_group.app_rg.location
  resource_group_name = azurerm_resource_group.app_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mgmt.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox_pip.id
  }
}

# 4. The Linux Virtual Machine Compute Engine
resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                = "vm-jumpbox-dev"
  location            = azurerm_resource_group.app_rg.location
  resource_group_name = azurerm_resource_group.app_rg.name
  size                = "Standard_F2as_v7"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.jumpbox_nic.id
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_azure_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}