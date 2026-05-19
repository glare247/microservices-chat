# ═══════════════════════════════════════════════════════════════
# TERRAFORM CONFIGURATION
# ═══════════════════════════════════════════════════════════════
terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "microservices-chat-tfstate"
    prefix = "terraform/state"
  }
}

# ═══════════════════════════════════════════════════════════════
# PROVIDER
# ═══════════════════════════════════════════════════════════════
provider "google" {
  project = var.project_id
  region  = var.region
}

# ═══════════════════════════════════════════════════════════════
# DATA SOURCE
# ═══════════════════════════════════════════════════════════════
data "google_compute_default_service_account" "default" {
  project = var.project_id
}