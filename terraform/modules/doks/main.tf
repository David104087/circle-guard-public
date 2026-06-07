terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.40"
    }
  }
}

data "digitalocean_kubernetes_versions" "available" {}

resource "digitalocean_kubernetes_cluster" "cluster" {
  name    = var.cluster_name
  region  = var.region
  version = data.digitalocean_kubernetes_versions.available.latest_version
  tags    = concat(["circleguard", var.environment, "provider:digitalocean"], var.tags)

  # Control plane is FREE on DOKS — no charge for the master nodes
  node_pool {
    name       = "default-pool"
    size       = var.node_size
    node_count = var.node_count

    # min_nodes=0 enables scale-to-zero between sessions — same pattern as GKE min_node_count=0
    auto_scale = true
    min_nodes  = var.min_nodes
    max_nodes  = var.max_nodes

    labels = {
      cluster     = var.cluster_name
      environment = var.environment
      provider    = "digitalocean"
    }
  }

  # Destroy protection off — same pattern as GKE module
  destroy_all_associated_resources = true
}
