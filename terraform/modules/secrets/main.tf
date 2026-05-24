resource "google_secret_manager_secret" "secret" {
  for_each  = var.secrets
  project   = var.project_id
  secret_id = each.key

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    managed-by  = "terraform"
  }
}
