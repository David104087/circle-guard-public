resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = "cg-gke-${substr(var.cluster_name, 13, -1)}"
  display_name = "GKE Node SA for ${var.cluster_name}"
}

resource "google_project_iam_member" "gke_nodes_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_container_cluster" "cluster" {
  project  = var.project_id
  name     = var.cluster_name
  location = var.region

  network    = var.network_id
  subnetwork = var.subnet_id

  # Remove default node pool immediately after cluster creation.
  # node_config here applies to the temporary initial pool (pd-standard avoids SSD quota).
  remove_default_node_pool = true
  initial_node_count       = 1

  node_config {
    disk_type    = "pd-standard"
    disk_size_gb = 30
    machine_type = "e2-medium"
  }

  # VPC-native networking (required for Istio and modern GKE)
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Disable legacy client certificate auth
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Allow terraform destroy (google provider 5.x defaults this to true)
  deletion_protection = false

  # Enable Dataplane V2 (required for NetworkPolicy on GKE)
  datapath_provider = "ADVANCED_DATAPATH"

  lifecycle {
    ignore_changes = [initial_node_count, node_config]
  }
}

resource "google_container_node_pool" "nodes" {
  project  = var.project_id
  name     = "default-pool"
  location = var.region
  cluster  = google_container_cluster.cluster.name

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  initial_node_count = var.node_count

  node_config {
    machine_type    = var.machine_type
    spot            = var.use_spot
    disk_size_gb    = var.disk_size_gb
    disk_type       = "pd-standard"
    service_account = google_service_account.gke_nodes.email

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      cluster     = var.cluster_name
      environment = split("-", var.cluster_name)[1]
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 0
    max_unavailable = 1
  }
}
