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

### APPLICATION INSIGHTS ###
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace
resource "azurerm_log_analytics_workspace" "workspace" {
  name                = "log-analytics-${var.app_insights_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
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

### LOGIC APP ###
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_standard
resource "azurerm_logic_app_standard" "example" {
  name                       = var.logic_app_name
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_service_plan.asp.id
  storage_account_name       = var.storage_account_name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  site_config {
    application_insights_connection_string = azurerm_application_insights.app_insights.connection_string
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"     = "node"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
  }
}

