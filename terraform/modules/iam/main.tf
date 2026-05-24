locals {
  env_short = substr(var.environment, 0, 1) # d, s, p

  # All service accounts to create. SA IDs are max 30 chars.
  service_accounts = merge(
    {
      "cg-jenkins-${var.environment}" = "Jenkins CI SA ${var.environment}"
      "cg-eso-${var.environment}"     = "External Secrets Operator SA ${var.environment}"
    },
    { for svc in var.microservices :
      "cg-${svc}-${var.environment}" => "CircleGuard ${svc} SA ${var.environment}"
    }
  )
}

resource "google_service_account" "sa" {
  for_each     = local.service_accounts
  project      = var.project_id
  account_id   = each.key
  display_name = each.value
}

# ESO needs Secret Manager access
resource "google_project_iam_member" "eso_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.sa["cg-eso-${var.environment}"].email}"
}

# Workload Identity bindings — allows K8s SAs to impersonate GCP SAs
resource "google_service_account_iam_member" "workload_identity" {
  for_each = local.service_accounts

  service_account_id = google_service_account.sa[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${each.key}]"
}
