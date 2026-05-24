variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "location" {
  type        = string
  description = "Artifact Registry location"
  default     = "us-central1"
}

variable "repository_id" {
  type        = string
  description = "Artifact Registry repository ID"
  default     = "circleguard"
}
