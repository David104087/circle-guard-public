output "service_account_emails" {
  value       = { for k, v in google_service_account.sa : k => v.email }
  description = "Map of SA name to email address"
}

output "eso_sa_email" {
  value       = google_service_account.sa["cg-eso-${var.environment}"].email
  description = "Email of the External Secrets Operator service account"
}

output "jenkins_sa_email" {
  value       = google_service_account.sa["cg-jenkins-${var.environment}"].email
  description = "Email of the Jenkins service account"
}
