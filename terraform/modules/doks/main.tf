terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.40"
    }
  }
}

data "digitalocean_kubernetes_versions" "available" {
  version_prefix = "${var.kubernetes_version}."
}

resource "digitalocean_kubernetes_cluster" "cluster" {
  name    = var.cluster_name
  region  = var.region
  version = data.digitalocean_kubernetes_versions.available.latest_version

  # Control plane is FREE on DOKS — no charge for the master nodes
  node_pool {
    name       = "default-pool"
    size       = var.node_size
    node_count = var.node_count

    auto_scale = true
    min_nodes  = var.min_nodes
    max_nodes  = var.max_nodes

    labels = {
      cluster     = var.cluster_name
      environment = "cloud2"
      provider    = "digitalocean"
    }
  }

  # Destroy protection off — same pattern as GKE module
  destroy_all_associated_resources = true
}
