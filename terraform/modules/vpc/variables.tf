variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "name" {
  type        = string
  description = "Name prefix for VPC and subnet resources"
}

variable "subnet_cidr" {
  type        = string
  description = "Primary CIDR for the subnet (nodes)"
}

variable "pods_cidr" {
  type        = string
  description = "Secondary CIDR for GKE pods"
}

variable "services_cidr" {
  type        = string
  description = "Secondary CIDR for GKE services"
}
