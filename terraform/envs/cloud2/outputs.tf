output "cluster_name" {
  value = module.doks.cluster_name
}

output "cluster_id" {
  value = module.doks.cluster_id
}

output "endpoint" {
  value     = module.doks.endpoint
  sensitive = true
}
