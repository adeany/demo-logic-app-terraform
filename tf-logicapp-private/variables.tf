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

variable "vm_pip_name" {
  type = string
  description = "VM Public IP name"
  default = "pip-vm-jumpbox"
}

variable "vm_jumpbox_name" {
  type = string
  description = "Jump Box VM hostname"
}

variable "vm_jumpbox_sku" {
  type = string
  description = "SKU for Jump Box VM"
  default = "Standard_DS2_v2"
}

variable "vm_jumpbox_user" {
  type = string
  description = "Username for shared admin account (when using ssh key auth)"
}

variable "storage_account_name" {
  type = string
  description = "Storage account name"
}

variable "app_plan_name" {
  type = string
  description = "App Service Plan name"
}

variable "app_plan_os_type" {
    type = string
    description = "App Service Plan OS type"
}

variable "app_plan_sku" {
  type = string
  description = "App Service Plan SKU"
}

variable "logic_app_name" {
  type = string
  description = "Logic App name"
}