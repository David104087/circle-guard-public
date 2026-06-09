variable "cluster_name" {
  type        = string
  description = "Name of the DOKS cluster"
}

variable "region" {
  type        = string
  description = "DigitalOcean region slug (e.g. nyc1, sfo3, lon1)"
  default     = "nyc1"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version prefix (e.g. '1.31'). Uses latest patch in that minor."
  default     = "1.31"
}

variable "node_count" {
  type        = number
  description = "Number of nodes in the default node pool"
  default     = 2
}

variable "min_nodes" {
  type        = number
  description = "Minimum nodes for autoscaling"
  default     = 0
}

variable "max_nodes" {
  type        = number
  description = "Maximum nodes for autoscaling"
  default     = 3
}

variable "node_size" {
  type        = string
  description = "Droplet size slug for nodes. s-2vcpu-4gb = ~$18/mo, s-2vcpu-2gb = ~$12/mo"
  default     = "s-2vcpu-4gb"
}

variable "environment" {
  type        = string
  description = "Environment label applied to node pool labels (dev, stage, prod)."
  default     = "dev"
}

variable "tags" {
  type        = list(string)
  description = "Additional tags to attach to the cluster."
  default     = []
}
