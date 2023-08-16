# Resource Group
rg_name = "TEST-amd-logic-app-02"
location = "westus3"

# Networking
vnet_name = "vnet-amd-logic-app-02"
vnet_address_space = [
  "10.16.56.0/24"
]

snet_common_name = "snet-common-amd-logic-app-02"
snet_common_cidr = "10.16.56.0/26"

snet_appplan_name = "snet-appplan-amd-logic-app-02"
snet_appplan_cidr = "10.16.56.128/26"

# Storage
storage_account_name = "storamdlogicapp02"

# APP SERVICE PLAN
app_plan_name = "asp-amd-logic-app-02"
app_plan_sku = "WS1"

# App Insights
log_analytics_workspace_sku = "PerGB2018"
app_insights_name = "ai-amd-logic-app-02"

# Logic App
logic_app_name = "logic-app-amd-02b"