variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region (regional cluster)"
}

variable "cluster_name" {
  type        = string
  description = "Name of the GKE cluster"
}

variable "network_id" {
  type        = string
  description = "Self-link of the VPC network"
}

variable "subnet_id" {
  type        = string
  description = "Self-link of the subnet"
}

variable "pods_range_name" {
  type        = string
  description = "Name of the secondary range for pods"
}

variable "services_range_name" {
  type        = string
  description = "Name of the secondary range for services"
}

variable "node_count" {
  type        = number
  description = "Initial node count per zone"
  default     = 1
}

variable "min_node_count" {
  type        = number
  description = "Minimum node count per zone for autoscaling"
  default     = 0
}

variable "max_node_count" {
  type        = number
  description = "Maximum node count per zone for autoscaling"
  default     = 3
}

variable "machine_type" {
  type        = string
  description = "Machine type for nodes"
  default     = "e2-standard-2"
}

variable "use_spot" {
  type        = bool
  description = "Use Spot VMs for nodes (up to 80% cheaper, can be preempted)"
  default     = false
}

variable "disk_size_gb" {
  type        = number
  description = "Boot disk size in GB per node"
  default     = 50
}
