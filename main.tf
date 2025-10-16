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

# Variables
variable "admin_username" {
  description = "Admin username for VM"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Admin password for VM"
  type        = string
  sensitive   = true
}

# Locals for reusable values
locals {
  location = "East US 2"  # Keeping original region
  rg_name  = "demo1"
  
  nsg_rules = {
    http  = { priority = 100, port = 80 }
    https = { priority = 110, port = 443 }
    rdp   = { priority = 120, port = 3389 }
  }
  
  web_vm_count = 2
  
  common_vm_config = {
    size            = "Standard_D2s_v3"  # Most reliable availability
    admin_username  = var.admin_username
    admin_password  = var.admin_password
    publisher       = "MicrosoftWindowsServer"
    offer           = "WindowsServer"
    sku             = "2022-Datacenter"
    version         = "latest"
  }
  
  schedules = {
    start = { time = "08:00", description = "Start all VMs at 8 AM on weekdays" }
    stop  = { time = "17:00", description = "Stop all VMs at 5 PM on weekdays" }
  }
}

# Resource Group
resource "azurerm_resource_group" "demo1" {
  name     = local.rg_name
  location = local.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnetdemo1" {
  name                = "vnetdemo1"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.demo1.location
  resource_group_name = azurerm_resource_group.demo1.name
}

# Subnet
resource "azurerm_subnet" "subnetdemo1" {
  name                 = "subnetdemo1"
  resource_group_name  = azurerm_resource_group.demo1.name
  virtual_network_name = azurerm_virtual_network.vnetdemo1.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group with dynamic rules
resource "azurerm_network_security_group" "nsg_demo1" {
  name                = "nsg-demo1"
  location            = azurerm_resource_group.demo1.location
  resource_group_name = azurerm_resource_group.demo1.name

  dynamic "security_rule" {
    for_each = local.nsg_rules
    content {
      name                       = "Allow-${upper(security_rule.key)}"
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.port
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}

# Associate NSG with Subnet
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnetdemo1.id
  network_security_group_id = azurerm_network_security_group.nsg_demo1.id
}

# Public IPs
resource "azurerm_public_ip" "pips" {
  for_each            = toset(["standalone", "loadbalancer"])
  name                = "pip-${each.key}"
  location            = azurerm_resource_group.demo1.location
  resource_group_name = azurerm_resource_group.demo1.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NIC for standalone VM
resource "azurerm_network_interface" "nic_standalone" {
  name                = "nic-demo1-vm"
  location            = azurerm_resource_group.demo1.location
  resource_group_name = azurerm_resource_group.demo1.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnetdemo1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pips["standalone"].id
  }
}

# Standalone VM
resource "azurerm_windows_virtual_machine" "vm_standalone" {
  name                  = "vm-demo1"
  location              = azurerm_resource_group.demo1.location
  resource_group_name   = azurerm_resource_group.demo1.name
  size                  = local.common_vm_config.size
  admin_username        = local.common_vm_config.admin_username
  admin_password        = local.common_vm_config.admin_password
  network_interface_ids = [azurerm_network_interface.nic_standalone.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = local.common_vm_config.publisher
    offer     = local.common_vm_config.offer
    sku       = local.common_vm_config.sku
    version   = local.common_vm_config.version
  }

  identity {
    type = "SystemAssigned"
  }
}

# Load Balancer
resource "azurerm_lb" "web_lb" {
  name                = "lb-web"
  location            = azurerm_resource_group.demo1.location
  resource_group_name = azurerm_resource_group.demo1.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.pips["loadbalancer"].id
  }
}

# Backend Pool
resource "azurerm_lb_backend_address_pool" "web_backend" {
  loadbalancer_id = azurerm_lb.web_lb.id
  name            = "BackendPool"
}

# Health Probe
resource "azurerm_lb_probe" "http_probe" {
  loadbalancer_id = azurerm_lb.web_lb.id
  name            = "http-probe"
  protocol        = "Http"
  port            = 80
  request_path    = "/"
}

# LB Rule
resource "azurerm_lb_rule" "http_rule" {
  loadbalancer_id                = azurerm_lb.web_lb.id
  name                           = "HTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web_backend.id]
  probe_id                       = azurerm_lb_probe.http_probe.id
  # Remove or comment out load_distribution for true round-robin per connection
  # load_distribution            = "SourceIP"
}

# Availability Set
resource "azurerm_availability_set" "web_avset" {
  name                = "avset-web"
  location            = azurerm_resource_group.demo1.location
  resource_group_name = azurerm_resource_group.demo1.name
  managed             = true
}

# NICs for Web VMs
resource "azurerm_network_interface" "web_nic" {
  count               = local.web_vm_count
  name                = "nic-web-${count.index + 1}"
  location            = azurerm_resource_group.demo1.location
  resource_group_name = azurerm_resource_group.demo1.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnetdemo1.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Associate NICs with Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "web_nic_backend" {
  count                   = local.web_vm_count
  network_interface_id    = azurerm_network_interface.web_nic[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_backend.id
}

# Web VMs
resource "azurerm_windows_virtual_machine" "web_vm" {
  count               = local.web_vm_count
  name                = "vm-web-${count.index + 1}"
  location            = azurerm_resource_group.demo1.location
  resource_group_name = azurerm_resource_group.demo1.name
  size                = local.common_vm_config.size
  admin_username      = local.common_vm_config.admin_username
  admin_password      = local.common_vm_config.admin_password
  availability_set_id = azurerm_availability_set.web_avset.id
  network_interface_ids = [azurerm_network_interface.web_nic[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = local.common_vm_config.publisher
    offer     = local.common_vm_config.offer
    sku       = local.common_vm_config.sku
    version   = local.common_vm_config.version
  }

  identity {
    type = "SystemAssigned"
  }
}

# IIS Installation Extension
resource "azurerm_virtual_machine_extension" "web_iis" {
  count                = local.web_vm_count
  name                 = "install-iis"
  virtual_machine_id   = azurerm_windows_virtual_machine.web_vm[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"Install-WindowsFeature -Name Web-Server -IncludeManagementTools; Remove-Item -Path C:\\inetpub\\wwwroot\\iisstart.htm -Force; Set-Content -Path C:\\inetpub\\wwwroot\\index.html -Value '<html><head><title>Hello World</title></head><body><h1>Hello World from VM ${count.index + 1}</h1><p>Served by: vm-web-${count.index + 1}</p></body></html>'\""
  })
}

# NOTE: Automation Account requires service principal with "User Access Administrator" 
# or "Owner" role to create role assignments. Comment out this section if you get 
# authorization errors, or grant additional permissions to your service principal.

# Automation Account
resource "azurerm_automation_account" "auto_demo1" {
  count               = 1  # Set to 1 to enable auto start/stop
  name                = "aa-demo1-startstop"
  location            = azurerm_resource_group.demo1.location
  resource_group_name = azurerm_resource_group.demo1.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }
}

# Role Assignment
resource "azurerm_role_assignment" "auto_contributor" {
  count                = 1  # Set to 1 to enable auto start/stop
  scope                = azurerm_resource_group.demo1.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_automation_account.auto_demo1[0].identity[0].principal_id
}

# Runbooks (Start and Stop)
resource "azurerm_automation_runbook" "vm_runbooks" {
  for_each                = length(azurerm_automation_account.auto_demo1) > 0 ? { start = "Start", stop = "Stop" } : {}
  name                    = "${each.value}-AllVMs"
  location                = azurerm_resource_group.demo1.location
  resource_group_name     = azurerm_resource_group.demo1.name
  automation_account_name = azurerm_automation_account.auto_demo1[0].name
  log_verbose             = true
  log_progress            = true
  runbook_type            = "PowerShell"

  content = templatefile("${path.module}/runbooks/${each.key}_vm.ps1", {
    action = each.value
  })
}

# Schedules
resource "azurerm_automation_schedule" "vm_schedules" {
  for_each                = length(azurerm_automation_account.auto_demo1) > 0 ? local.schedules : {}
  name                    = "${title(each.key)}-VMs-Schedule"
  resource_group_name     = azurerm_resource_group.demo1.name
  automation_account_name = azurerm_automation_account.auto_demo1[0].name
  frequency               = "Week"
  interval                = 1
  timezone                = "America/Puerto_Rico"
  start_time              = timeadd(timestamp(), "24h")
  week_days               = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
  description             = each.value.description
}

# Job Schedules
resource "azurerm_automation_job_schedule" "job_schedules" {
  for_each                = length(azurerm_automation_account.auto_demo1) > 0 ? local.schedules : {}
  resource_group_name     = azurerm_resource_group.demo1.name
  automation_account_name = azurerm_automation_account.auto_demo1[0].name
  schedule_name           = azurerm_automation_schedule.vm_schedules[each.key].name
  runbook_name            = azurerm_automation_runbook.vm_runbooks[each.key].name

  parameters = {
    resourcegroupname = azurerm_resource_group.demo1.name
  }
}

# Outputs
output "standalone_vm_public_ip" {
  value = azurerm_public_ip.pips["standalone"].ip_address
}

output "load_balancer_url" {
  value = "http://${azurerm_public_ip.pips["loadbalancer"].ip_address}"
}

output "web_vm_names" {
  value = azurerm_windows_virtual_machine.web_vm[*].name
}

output "automation_account_name" {
  value = length(azurerm_automation_account.auto_demo1) > 0 ? azurerm_automation_account.auto_demo1[0].name : "Not deployed - enable in main.tf"
}