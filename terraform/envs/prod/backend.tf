terraform {
  backend "gcs" {
    bucket = "circle-guard-tfstate-496702"
    prefix = "envs/prod"
  }
}
