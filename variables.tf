variable "region" {
  type = string
  description = "Desired Azure Region"
  default     = "northeurope"
}

variable "Topic_connection_string" {
  type = string
  default = ""
}

variable "Topic_name" {
  type = string
  default = ""
}

variable "environment_name" {
  type = string
  default = ""
}