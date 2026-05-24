variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, stage, prod)"
}

variable "microservices" {
  type        = list(string)
  description = "List of microservice short names (auth, dashboard, file, form, notification, promotion)"
  default     = ["auth", "dashboard", "file", "form", "notification", "promotion"]
}

variable "k8s_namespace" {
  type        = string
  description = "Kubernetes namespace where microservice pods run"
}
