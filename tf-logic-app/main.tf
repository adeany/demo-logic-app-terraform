variable "rg_name" {
  type = string
}

variable "location" {
  type = string
  default = "westus3"
}

variable "vnet_name" {
  type = string
  description = "Virtual Network name"
}

variable "vnet_address_space" {
  type = list(string)
  description = "Virtual network IP address space"
}

variable "snet_common_name" {
  type = string
  description = "Common subnet name"
}

variable "snet_common_cidr" {
  type = string
  description = "CIDR for Common subnet"
}

variable "snet_appplan_name" {
  type = string
  description = "AppPlan subnet name"
}
  
variable "snet_appplan_cidr" {
  type = string
  description = "CIDR for AppPlan subnet"
}

variable "storage_account_name" {
  type = string
  description = "Storage account name"
}

variable "app_plan_name" {
  type = string
  description = "App Service Plan name"
}

variable "app_plan_sku" {
  type = string
  description = "App Service Plan SKU"
}

variable "log_analytics_workspace_sku" {
  type = string
  description = "Log Analytics Workspace SKU"
}

variable "logic_app_name" {
  type = string
  description = "Logic App name"
}

variable "app_insights_name" {
  type = string
  description = "Application Insights name"
}

terraform {
  required_version = ">= 0.14"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.69.0"
    }
  }
}

provider "azurerm" {
  # Configuration options
  features {}
}

### NETWORKING ###
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

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
  name                = var.storage_account_name
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

### APPLICATION INSIGHTS ###
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace
resource "azurerm_log_analytics_workspace" "workspace" {
  name                = "log-analytics-${var.app_insights_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = var.log_analytics_workspace_sku
  retention_in_days   = 30
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights
resource "azurerm_application_insights" "app_insights" {
  name                = var.app_insights_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.workspace.id
  application_type    = "web"
}

### APP PLAN ###
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan
resource "azurerm_service_plan" "asp" {
  name                = var.app_plan_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = var.app_plan_sku
}

# Creating the storage share ahead of time allows us to attach to a private storage account
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_share
resource "azurerm_storage_share" "share" {
  name                 = "${var.logic_app_name}-content"
  storage_account_name = azurerm_storage_account.storage.name
  access_tier          = "TransactionOptimized"
  quota                = 5120

  depends_on = [
    azurerm_storage_account.storage
  ]
}

### LOGIC APP ###
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_standard
resource "azurerm_logic_app_standard" "logic_app" {
  name                       = var.logic_app_name
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_service_plan.asp.id
  storage_account_name       = var.storage_account_name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"     = "node"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
    "WEBSITE_CONTENTOVERVNET" = "1"
    "WEBSITE_VNET_ROUTE_ALL" = "1"
  }

  depends_on = [
    azurerm_storage_share.share
  ]
}

