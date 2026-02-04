resource "google_sql_database_instance" "postgres" {
  name             = "${var.project}-${var.environment}-sql"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier              = "db-custom-8-32768"
    availability_type = "REGIONAL" # HA
    disk_size         = 500
    disk_type         = "PD_SSD"
    
    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_self_link
    }
  }

  encryption_key_name = var.kms_key_name
  deletion_protection = true
}

resource "google_spanner_instance" "rx_spanner" {
  name         = "mediconnect-rx"
  config       = "regional-${var.region}"
  display_name = "Prescription Spanner"
  num_nodes    = 1
  
  labels = {
    "environment" = var.environment
  }
}

resource "google_spanner_database" "rx_db" {
  instance = google_spanner_instance.rx_spanner.name
  name     = "mediconnect-rx-db"
  encryption_config {
    kms_key_name = var.kms_key_name
  }
  deletion_protection = false # For Terraform destroyer ease, set true in real prod
}

resource "google_bigquery_dataset" "analytics" {
  dataset_id                  = "mediconnect_analytics"
  friendly_name               = "MediConnect Analytics"
  description                 = "HIPAA-compliant analytics dataset"
  location                    = var.region
  default_table_expiration_ms = 3600000

  labels = {
    env = var.environment
  }
}

resource "google_storage_bucket" "medical_images" {
  name          = "${var.project}-${var.environment}-medical-images"
  location      = "US" # Multi-region
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = var.kms_key_name
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }
}
