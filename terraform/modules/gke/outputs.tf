output "cluster_name" {
  value       = google_container_cluster.cluster.name
  description = "GKE cluster name"
}

output "cluster_endpoint" {
  value       = google_container_cluster.cluster.endpoint
  description = "GKE cluster API endpoint"
  sensitive   = true
}

output "cluster_ca_certificate" {
  value       = google_container_cluster.cluster.master_auth[0].cluster_ca_certificate
  description = "Base64-encoded cluster CA certificate"
  sensitive   = true
}

output "node_sa_email" {
  value       = google_service_account.gke_nodes.email
  description = "Email of the GKE node service account"
}
