terraform {
  required_version = ">= 1.6"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.40"
    }
  }

  backend "gcs" {
    bucket = "circle-guard-tfstate-496702"
    prefix = "envs/cloud2"
  }
}

# Token provided via environment variable: export DO_TOKEN="dop_v1_..."
# Never hardcode the token here.
provider "digitalocean" {
  token = var.do_token
}

module "doks" {
  source = "../../modules/doks"

  cluster_name       = "circleguard-cloud2"
  region             = var.region
  kubernetes_version = "1.31"
  node_count         = 2
  min_nodes          = 1
  max_nodes          = 3
  node_size          = "s-2vcpu-4gb"
}
