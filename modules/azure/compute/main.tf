resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.project}-${var.environment}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.project}-${var.environment}"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_D4s_v5"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  tags = {
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# --- Function App (Symptom Checker) ---

resource "azurerm_storage_account" "func_sa" {
  name                     = "${var.project}${var.environment}funcsa" # Generic name logic
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "func_plan" {
  name                = "${var.project}-${var.environment}-func-plan"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption
}

resource "null_resource" "install_symptom_deps" {
  triggers = {
    requirements = filemd5("${path.module}/../../../src/symptom-checker/requirements.txt")
  }

  provisioner "local-exec" {
    command = "pip install -r ${path.module}/../../../src/symptom-checker/requirements.txt -t ${path.module}/../../../src/symptom-checker/"
  }
}

data "archive_file" "symptom_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src/symptom-checker"
  output_path = "${path.module}/../../../src/symptom-checker/symptom-checker.zip"
  depends_on  = [null_resource.install_symptom_deps]
}

# Upload to Blob Storage manually for Function App or rely on zip deployment. 
# For simplicity in this structure, assume zip deploy via CLI or separate CD pipeline usually.
# But for Terraform-managed, we'd upload to blob and set WEBSITE_RUN_FROM_PACKAGE.

resource "azurerm_storage_container" "deployments" {
  name                  = "function-releases"
  storage_account_name  = azurerm_storage_account.func_sa.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "symptom_code" {
  name                   = "symptom-checker.zip"
  storage_account_name   = azurerm_storage_account.func_sa.name
  storage_container_name = azurerm_storage_container.deployments.name
  type                   = "Block"
  source                 = data.archive_file.symptom_zip.output_path
}

resource "azurerm_linux_function_app" "symptom_checker" {
  name                = "${var.project}-${var.environment}-symptom-checker"
  resource_group_name = var.resource_group_name
  location            = var.location

  storage_account_name       = azurerm_storage_account.func_sa.name
  storage_account_access_key = azurerm_storage_account.func_sa.primary_access_key
  service_plan_id            = azurerm_service_plan.func_plan.id

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = azurerm_storage_blob.symptom_code.url
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "AzureWebJobsStorage"      = azurerm_storage_account.func_sa.primary_connection_string
  }
}
