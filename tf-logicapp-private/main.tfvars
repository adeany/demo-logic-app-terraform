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

# VM JUMPBOX
vm_pip_name = "pip-vm-jumpbox-logicapp-amd-test-tf"
vm_jumpbox_name = "vm-jumpbox-logicapp-amd-test-tf"
vm_jumpbox_sku = "Standard_DS2_v2"
vm_jumpbox_user = "azureuser"

# Storage
storage_account_name = "storamdlogicapp02"

# APP SERVICE PLAN
app_plan_name = "asp-amd-logic-app-02"
app_plan_os_type = "Windows"
app_plan_sku = "WS1"

# Logic App
logic_app_name = "logic-app-amd-02b"