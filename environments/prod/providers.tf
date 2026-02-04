terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.6"
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "MediConnect"
      Environment = "Production"
      ManagedBy   = "Terraform"
    }
  }

  # Mocking for CI/CD Portfolio - No real credentials needed
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  
  # Mocking for CI/CD
  access_token = "mock_token"
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
  storage_use_azuread        = true

  # Mock Credentials
  client_id       = "00000000-0000-0000-0000-000000000000"
  client_secret   = "mock_secret"
  tenant_id       = "00000000-0000-0000-0000-000000000000"
  subscription_id = "00000000-0000-0000-0000-000000000000"
}
