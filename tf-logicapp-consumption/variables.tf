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
