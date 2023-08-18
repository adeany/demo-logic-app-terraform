terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.69.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Configuration options
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

### NETWORKING ###
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network
resource "azurerm_virtual_network" "vnet" {
  name = var.vnet_name
  location = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space = var.vnet_address_space
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
resource "azurerm_subnet" "snet_common" {
  name = var.snet_common_name
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = [var.snet_common_cidr]
  private_endpoint_network_policies_enabled = false
}

resource "azurerm_subnet" "snet_appplan" {
  name = var.snet_appplan_name
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = [var.snet_appplan_cidr]

  delegation {
    name = "delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/network_security_group.html
resource "azurerm_network_security_group" "nsg_common" {
  name                = "nsg-common"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
resource "azurerm_network_security_group" "nsg_appplan" {
  name                = "nsg-appplan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association
resource "azurerm_subnet_network_security_group_association" "snet_nsg_common" {
  subnet_id                 = azurerm_subnet.snet_common.id
  network_security_group_id = azurerm_network_security_group.nsg_common.id
}
resource "azurerm_subnet_network_security_group_association" "snet_nsg_appplan" {
  subnet_id                 = azurerm_subnet.snet_appplan.id
  network_security_group_id = azurerm_network_security_group.nsg_appplan.id
}

### STORAGE ###
# Fetch local IP address for network rules
data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = false

  public_network_access_enabled = true
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]

    # Allow agent's IP access for file share creation
    # Not required if agent already has private network access
    ip_rules       = [chomp(data.http.myip.response_body)]
  }
}

# Private Endpoint - Blob
module "pe_blob" {
  source = "./modules/storage-pe"

  rg = azurerm_resource_group.rg
  vnet = azurerm_virtual_network.vnet
  subnet = azurerm_subnet.snet_common
  storage_account = azurerm_storage_account.storage
  subresource = "blob"
}

# Private Endpoint - Table
module "pe_table" {
  source = "./modules/storage-pe"

  rg = azurerm_resource_group.rg
  vnet = azurerm_virtual_network.vnet
  subnet = azurerm_subnet.snet_common
  storage_account = azurerm_storage_account.storage
  subresource = "table"
}

# Private Endpoint - Queue
module "pe_queue" {
  source = "./modules/storage-pe"

  rg = azurerm_resource_group.rg
  vnet = azurerm_virtual_network.vnet
  subnet = azurerm_subnet.snet_common
  storage_account = azurerm_storage_account.storage
  subresource = "queue"
}

# Private Endpoint - File
module "pe_file" {
  source = "./modules/storage-pe"

  rg = azurerm_resource_group.rg
  vnet = azurerm_virtual_network.vnet
  subnet = azurerm_subnet.snet_common
  storage_account = azurerm_storage_account.storage
  subresource = "file"
}

# ### APP PLAN ###
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan
resource "azurerm_service_plan" "asp" {
  name                = var.app_plan_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = var.app_plan_os_type
  sku_name            = var.app_plan_sku
}

### LOGIC APP ###
# Create a unique string to use as the suffix of the file share
# https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string
resource "random_string" "storage_share_suffix" {
  length  = 5
  numeric = false
  special = false
  upper   = false
}

# Creating the storage share ahead of time allows us to attach to a private storage account
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_share
resource "azurerm_storage_share" "share" {
  name                 = "${var.logic_app_name}-${random_string.storage_share_suffix.result}"
  storage_account_name = azurerm_storage_account.storage.name
  access_tier          = "TransactionOptimized"
  quota                = 5120
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_standard
resource "azurerm_logic_app_standard" "app" {
  name                       = var.logic_app_name
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_service_plan.asp.id
  virtual_network_subnet_id  = azurerm_subnet.snet_appplan.id

  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key
  storage_account_share_name = azurerm_storage_share.share.name

  version = "~4"
  https_only = true

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME     = "node"
    WEBSITE_NODE_DEFAULT_VERSION = "~18"
    WEBSITE_CONTENTOVERVNET      = "1"
  }

  site_config {
    vnet_route_all_enabled           = true
    dotnet_framework_version         = "v6.0"
    use_32_bit_worker_process        = false
    runtime_scale_monitoring_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }
}

# Private DNS Zone for Logic App
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone
resource "azurerm_private_dns_zone" "dns_zone_logicapp" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link
resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_pe_storage" {
  name = "privatelink.azurewebsites.net-${azurerm_virtual_network.vnet.name}"
  resource_group_name = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone_logicapp.name
  virtual_network_id = azurerm_virtual_network.vnet.id
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint
resource "azurerm_private_endpoint" "pe_logicapp" {
  name = "pe-${azurerm_logic_app_standard.app.name}"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id = azurerm_subnet.snet_common.id
  custom_network_interface_name = "pe-${azurerm_logic_app_standard.app.name}-nic"

  private_dns_zone_group {
    name = "dns-pe-${azurerm_logic_app_standard.app.name}"
    private_dns_zone_ids = [ azurerm_private_dns_zone.dns_zone_logicapp.id ]
  }

  private_service_connection {
    name = "plink-${azurerm_logic_app_standard.app.name}"
    is_manual_connection = false
    private_connection_resource_id = azurerm_logic_app_standard.app.id
    subresource_names = [ "sites" ]
  }
}

### VIRTUAL MACHINE (Jump Box) ###
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "pip_vm_jumpbox" {
  name                = var.vm_pip_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface
resource "azurerm_network_interface" "nic_vm_jumpbox" {
  name                = "${var.vm_jumpbox_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_common.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip_vm_jumpbox.id
  }
}

# https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key
resource "tls_private_key" "vm_jumphost_ssh_key" {
    algorithm = "RSA"
    rsa_bits = 4096
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
resource "azurerm_linux_virtual_machine" "vm_jumpbox" {
  name                = var.vm_jumpbox_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_jumpbox_sku
  admin_username      = var.vm_jumpbox_user
  network_interface_ids = [
    azurerm_network_interface.nic_vm_jumpbox.id,
  ]

  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = var.vm_jumpbox_user
    public_key = tls_private_key.vm_jumphost_ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.vm_jumpbox_name}-os-disk"
  }

  # az vm image list-offers -l westus3 --publisher Canonical --query "[?contains(name, 'focal')]"
  # az vm image list-skus -l westus3 --publisher Canonical --offer 0001-com-ubuntu-server-focal
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension
# Connect with az ssh vm --ip $IP_ADDRESS
resource "azurerm_virtual_machine_extension" "vm_jumpbox_aadlogin" {
  name                 = "AADSSHLogin"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm_jumpbox.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADSSHLoginForLinux"
  type_handler_version = "1.0"
}
