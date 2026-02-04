resource "google_container_cluster" "primary" {
  name     = "${var.project}-${var.environment}-gke"
  location = var.region

  # Regional cluster for HA
  network    = var.network_name
  subnetwork = var.subnet_name

  # Initial node count per zone
  initial_node_count = 1

  # Remove default node pool
  remove_default_node_pool = true

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Private Cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false 
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  release_channel {
    channel = "REGULAR"
  }
}

resource "google_container_node_pool" "system_pool" {
  name       = "system-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    machine_type = "e2-standard-4"
    disk_size_gb = 100
    preemptible  = false
    service_account = google_service_account.node_sa.email
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

resource "google_container_node_pool" "app_pool" {
  name       = "app-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 10
  }

  node_config {
    machine_type = "n2-standard-8"
    disk_size_gb = 100
    preemptible  = true
    service_account = google_service_account.node_sa.email
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    taint {
      key    = "preemptible"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }
}

resource "google_container_node_pool" "gpu_pool" {
  name       = "gpu-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  autoscaling {
    min_node_count = 0
    max_node_count = 5
  }

  node_config {
    machine_type = "n1-standard-4"
    disk_size_gb = 100
    preemptible  = false

    guest_accelerator {
      type  = "nvidia-tesla-t4"
      count = 1
    }

    # GPU Sharing (Time-slicing) - Requires experimental feature or distinct config usually, 
    # but strictly setting accelerator here. 
    # Time-sharing involves installing drivers and config which is post-provisioning or custom image.
    
    service_account = google_service_account.node_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    
    labels = {
      role = "ai-inference"
      workload = "medical-imaging"
    }

    taint {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NO_SCHEDULE"
    }
  }
}

resource "google_service_account" "node_sa" {
  account_id   = "${var.environment}-gke-node-sa"
  display_name = "GKE Node Service Account"
}

# --- Cloud Function (EHR/FHIR) ---

resource "google_storage_bucket" "function_bucket" {
  name     = "${var.project}-${var.environment}-functions"
  location = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "ehr_archive" {
  name   = "ehr-fhir.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "${path.module}/../../../src/ehr-fhir/ehr-fhir.zip"
  depends_on = [data.archive_file.ehr_zip]
}

resource "google_cloudfunctions_function" "ehr_function" {
  name        = "${var.project}-${var.environment}-ehr-service"
  description = "EHR and Digital Signature Service"
  runtime     = "python311"
  region      = var.region

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.function_bucket.name
  source_archive_object = google_storage_bucket_object.ehr_archive.name
  trigger_http          = true
  entry_point           = "handler"
}

resource "null_resource" "install_ehr_deps" {
  triggers = {
    requirements = filemd5("${path.module}/../../../src/ehr-fhir/requirements.txt")
  }

  provisioner "local-exec" {
    command = "pip install -r ${path.module}/../../../src/ehr-fhir/requirements.txt -t ${path.module}/../../../src/ehr-fhir/"
  }
}

data "archive_file" "ehr_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src/ehr-fhir"
  output_path = "${path.module}/../../../src/ehr-fhir/ehr-fhir.zip"
  depends_on  = [null_resource.install_ehr_deps]
}
