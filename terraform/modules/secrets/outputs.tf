output "secret_ids" {
  value       = { for k, v in google_secret_manager_secret.secret : k => v.id }
  description = "Map of secret name to full Secret Manager resource ID"
}
