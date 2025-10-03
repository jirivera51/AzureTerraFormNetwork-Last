terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "azurerm" {
  features {}
}

# 1 - Resource Group
resource "azurerm_resource_group" "demo1" {
  name     = "demo1"
  location = "East US"
}

# 2 - Virtual Network
resource "azurerm_virtual_network" "vnetdemo1" {
  name                = "vnetdemo1"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.demo1.location
  resource_group_name = azurerm_resource_group.demo1.name
}

# 3 - Subnet
resource "azurerm_subnet" "subnetdemo1" {
  name                 = "subnetdemo1"
  resource_group_name  = azurerm_resource_group.demo1.name
  virtual_network_name = azurerm_virtual_network.vnetdemo1.name
  address_prefixes     = ["10.0.1.0/24"]
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}