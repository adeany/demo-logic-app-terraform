terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.69.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "=1.6.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Configuration options
}

data "azurerm_subscription" "current" {}

# Enable Defender for Cloud
# https://techcommunity.microsoft.com/t5/microsoft-defender-for-cloud/deploy-microsoft-defender-for-cloud-via-terraform/ba-p/3563710

resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

data "azurerm_managed_api" "defender_assessment" {
  # This was created manually in the portal due to there is no defender tf resource yet
  name     = var.connection_name
  location = azurerm_resource_group.rg.location
  # id should look like this:
  # "/subscriptions/${data.azurerm_subscription.current.subscription_id}/providers/Microsoft.Web/locations/westus3/managedApis/ascassessment"
}

resource "azurerm_api_connection" "defender_api_connection" {
  name = var.connection_name
  resource_group_name = azurerm_resource_group.rg.name
  managed_api_id = data.azurerm_managed_api.defender_assessment.id
  display_name = "Microsoft Defender for Cloud Recommendation"
  parameter_values = {}
}

resource "azurerm_logic_app_workflow" "defender_to_pagerduty" {
  name                = var.logic_app_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  identity {
    type = "SystemAssigned"

  }

  workflow_parameters = {
    "$connections" = jsonencode({
      "defaultValue" : {},
      "type" : "Object"
    })
  }

  parameters = {
    "$connections" = jsonencode({
      "${data.azurerm_managed_api.defender_assessment.name}" : {
        "connectionId" : "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.Web/connections/${data.azurerm_managed_api.defender_assessment.name}",
        "connectionName" : "${data.azurerm_managed_api.defender_assessment.name}",
        "id" : "${data.azurerm_managed_api.defender_assessment.id}"
      }
    })
  }
}

resource "azurerm_logic_app_trigger_custom" "denfender_for_cloud" {
  # name         = var.trigger_name
  name = "When_a_Microsoft_Defender_for_Cloud_recommendation_is_created_or_triggered"
  logic_app_id = azurerm_logic_app_workflow.defender_to_pagerduty.id

  body = <<BODY
{  
  "inputs": {
    "body": {
        "callback_url": "@{listCallbackUrl()}"
    },
    "host": {
        "connection": {
            "name": "@parameters('$connections')['ascassessment']['connectionId']"
        }
    },
    "path": "/Microsoft.Security/Assessment/subscribe"
  },
  "type": "ApiConnectionWebhook"
}
BODY
}

# resource "azurerm_logic_app_action_custom" "defender_to_pagerduty_functionapp" {
  # depends_on = [
  #   azuread_application.defender_to_pagerduty_app_registration
  # ]

#   name         = var.function_app_name
#   logic_app_id = azurerm_logic_app_workflow.defender_to_pagerduty.id

#   body = <<BODY
# {    
#     "inputs": {
#         "authentication": {
#             "audience": "${azuread_application.defender_to_pagerduty_app_registration.application_id}",
#             "type": "ManagedServiceIdentity"
#         },
#         "body": "@triggerBody()",
#         "function": {
#             "id": "${azurerm_function_app_function.defender_to_pagerduty.id}"
#         }
#     },
#     "runAfter": {},
#     "type": "Function"    
# }    
# BODY
# }