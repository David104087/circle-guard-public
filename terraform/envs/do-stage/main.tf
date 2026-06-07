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
    prefix = "envs/do-stage"
  }
}

# Token provided via environment variable: export TF_VAR_do_token="dop_v1_..."
# Never hardcode the token here.
provider "digitalocean" {
  token = var.do_token
}

module "doks" {
  source = "../../modules/doks"

  cluster_name       = "circleguard-do-stage"
  region             = var.region
  kubernetes_version = "1.31"
  environment        = "stage"
  node_count         = 1
  min_nodes          = 0
  max_nodes          = 3
  node_size          = "s-2vcpu-4gb"
}
