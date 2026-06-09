variable "do_token" {
  type        = string
  description = "DigitalOcean Personal Access Token. Set via TF_VAR_do_token or DO_TOKEN env var."
  sensitive   = true
}

variable "region" {
  type        = string
  description = "DigitalOcean region slug"
  default     = "nyc1"
}
