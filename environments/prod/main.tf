module "aws_network" {
  source = "../../modules/aws/network"

  project              = var.project
  environment          = "prod"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  availability_zones   = ["${var.aws_region}a", "${var.aws_region}b"]
  kms_key_id           = var.aws_kms_key_id
}

module "aws_identity" {
  source = "../../modules/aws/identity"

  environment = "prod"
}

module "gcp_network" {
  source = "../../modules/gcp/network"

  project       = var.project
  environment   = "prod"
  region        = var.gcp_region
  subnet_cidr   = "10.1.0.0/20"
  pods_cidr     = "10.4.0.0/14"
  services_cidr = "10.8.0.0/20"
}

module "aws_compute" {
  source = "../../modules/aws/compute"
  project     = var.project
  environment = var.environment
  subnet_ids  = module.aws_network.private_subnet_ids
}

module "aws_data" {
  source = "../../modules/aws/data"
  project     = var.project
  environment = var.environment
  kms_key_arn = var.kms_key_arn
}

module "gcp_compute" {
  source = "../../modules/gcp/compute"

  project      = var.project
  project_id   = var.gcp_project_id
  environment  = "prod"
  region       = var.gcp_region
  network_name = module.gcp_network.network_name
  subnet_name  = module.gcp_network.subnet_name
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.project}-prod-rg"
  location = var.azure_location
}

module "azure_compute" {
  source = "../../modules/azure/compute"

  project             = var.project
  environment         = "prod"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.rg.name
}

module "azure_data" {
  source = "../../modules/azure/data"

  project             = var.project
  environment         = "prod"
  location            = var.azure_location
  failover_location   = var.azure_failover_location
  resource_group_name = azurerm_resource_group.rg.name
}
