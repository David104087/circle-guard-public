output "network_id" {
  value       = google_compute_network.vpc.id
  description = "Self-link of the VPC network"
}

output "network_name" {
  value       = google_compute_network.vpc.name
  description = "Name of the VPC network"
}

output "subnet_id" {
  value       = google_compute_subnetwork.subnet.id
  description = "Self-link of the subnet"
}

output "subnet_name" {
  value       = google_compute_subnetwork.subnet.name
  description = "Name of the subnet"
}

output "pods_range_name" {
  value       = "${var.name}-pods"
  description = "Name of the secondary IP range for GKE pods"
}

output "services_range_name" {
  value       = "${var.name}-services"
  description = "Name of the secondary IP range for GKE services"
}
