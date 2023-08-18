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

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_workflow
resource "azurerm_logic_app_workflow" "example" {
  name                = var.logic_app_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_trigger_http_request
resource "azurerm_logic_app_trigger_http_request" "example" {
  name         = "trigger-http"
  logic_app_id = azurerm_logic_app_workflow.example.id

  schema = <<SCHEMA
{
  "type": "object",
  "properties": {
    "name": {
      "type": "string"
    }
  }
}
SCHEMA

}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_action_custom
resource "azurerm_logic_app_action_custom" "example" {
  name         = "Response - Say Hello"
  logic_app_id = azurerm_logic_app_workflow.example.id

  body = <<BODY
{
  "inputs": {
    "body": {
      "response": "Hello, @{triggerBody()?['name']}"
    },
    "headers": {
      "Content-Type": "application/json"
    },
    "statusCode": 200
  },
  "kind": "Http",
  "runAfter": {},
  "type": "Response"
}
BODY

}

output "app_url" {
  value = azurerm_logic_app_trigger_http_request.example.callback_url
  description = "URL for the app's HTTP trigger."
}
