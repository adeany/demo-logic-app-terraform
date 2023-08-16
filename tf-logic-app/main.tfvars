# Resource Group
rg_name = "TEST-amd-logic-app-02"
location = "westus3"

# Networking
vnet_name = "vnet-amd-logic-app-02"
vnet_address_space = [
  "10.16.56.0/24"
]

# Storage
storage_account_name = "storamdlogicapp02"

# APP SERVICE PLAN
app_plan_name = "asp-amd-logic-app-02"
app_plan_sku = "EP1"

# App Insights
app_insights_name = "ai-amd-logic-app-02"

# Logic App
logic_app_name = "logic-app-amd-02b"