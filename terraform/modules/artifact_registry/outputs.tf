output "repository_url" {
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${var.repository_id}"
  description = "Full URL of the Artifact Registry Docker repository"
}

output "repository_id" {
  value       = google_artifact_registry_repository.circleguard.repository_id
  description = "Repository ID"
}
