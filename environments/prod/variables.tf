variable "project" {
  type    = string
  default = "mediconnect"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "aws_region" {
  type    = string
  default = "eu-central-1" # GDPR Compliance Default
}

variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type    = string
  default = "europe-west1" # GDPR Compliance Default
}

variable "azure_location" {
  type    = string
  default = "West Europe" # GDPR Compliance Default
}

variable "azure_failover_location" {
  type    = string
  default = "North Europe"
}

variable "aws_kms_key_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}
