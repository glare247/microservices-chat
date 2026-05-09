# ═══════════════════════════════════════════════════════════════
# TERRAFORM CONFIGURATION
# Provider and data sources only
# All resources split into dedicated files:
#   networking.tf — VPC subnets firewall
#   routing.tf    — Cloud Router NAT Gateway
#   gke.tf        — GKE cluster node pool
#   database.tf   — Cloud SQL PostgreSQL
#   dns.tf        — DNS records static IP
#   registry.tf   — Artifact Registry IAM
# ═══════════════════════════════════════════════════════════════
terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ═══════════════════════════════════════════════════════════════
# DATA SOURCE — GCP DEFAULT SERVICE ACCOUNT
# Gets GKE node service account email
# Used by registry.tf for Artifact Registry IAM
# ═══════════════════════════════════════════════════════════════
data "google_compute_default_service_account" "default" {
  project = var.project_id
}
