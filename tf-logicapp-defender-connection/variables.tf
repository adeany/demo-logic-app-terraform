variable "rg_name" {
  type = string
}

variable "location" {
  type = string
  default = "westus3"
}

# LOGIC APP
variable "logic_app_name" {
  type = string
  description = "Logic App name"
}

variable "connection_name" {
    type = string
    description = "Connection name"
}

variable "trigger_name" {
    type = string
    description = "Trigger name"
}

variable "function_app_name" {
    type = string
    description = "Function App name"
}