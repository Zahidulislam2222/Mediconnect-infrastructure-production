resource "azurerm_cosmosdb_account" "db" {
  name                = "${var.project}-${var.environment}-cosmos"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "MongoDB"

  automatic_failover_enabled = true

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.failover_location
    failover_priority = 1
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  tags = {
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}
resource "azurerm_healthcare_service" "fhir" {
  name                = "${var.project}${var.environment}fhir"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "fhir-R4"
  cosmosdb_throughput = 1000

  access_policy_object_ids = [
    # In production, add Managed Identity Object ID of the Function App or specific users
  ]

  authentication_configuration {
    authority = "https://login.microsoftonline.com/common"
    audience  = "https://${var.project}${var.environment}fhir.azurehealthcareapis.com"
    smart_proxy_enabled = true
  }

  cors_configuration {
    allow_credentials = true
    allowed_headers   = ["*"]
    allowed_methods   = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allowed_origins   = ["*"]
    max_age_in_seconds= 3600
  }
}
