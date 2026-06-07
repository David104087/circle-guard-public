output "cluster_id" {
  value       = digitalocean_kubernetes_cluster.cluster.id
  description = "DOKS cluster ID"
}

output "cluster_name" {
  value       = digitalocean_kubernetes_cluster.cluster.name
  description = "DOKS cluster name"
}

output "endpoint" {
  value       = digitalocean_kubernetes_cluster.cluster.endpoint
  description = "Kubernetes API server endpoint"
  sensitive   = true
}

output "kube_config" {
  value       = digitalocean_kubernetes_cluster.cluster.kube_config[0].raw_config
  description = "Raw kubeconfig for kubectl"
  sensitive   = true
}

output "cluster_urn" {
  value       = digitalocean_kubernetes_cluster.cluster.urn
  description = "URN for use in DigitalOcean Projects"
}
