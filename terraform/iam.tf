# ═══════════════════════════════════════════════════════════════
# IAM AND WORKLOAD IDENTITY FEDERATION
# Allows GitHub Actions to authenticate with GCP
# without storing JSON keys anywhere
#
# AUTHENTICATION FLOW:
#   GitHub generates OIDC token
#   GCP verifies token with GitHub
#   GCP checks attribute_condition rules
#   Temporary credentials issued (1 hour)
#   GitHub Actions performs CI/CD tasks
# ═══════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════
# SERVICE ACCOUNT — GitHub Actions
# Identity that GitHub Actions impersonates
# Limited permissions — principle of least privilege
# ═══════════════════════════════════════════════════════════════
resource "google_service_account" "github_actions" {
  account_id   = "github-actions"
  display_name = "GitHub Actions CI"
  description  = "Used by GitHub Actions CI/CD pipeline"
  project      = var.project_id
}

# ═══════════════════════════════════════════════════════════════
# WORKLOAD IDENTITY POOL
# Security zone that GitHub is allowed to enter
# ═══════════════════════════════════════════════════════════════
resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
  description               = "WIF pool for GitHub Actions CI pipeline"
  project                   = var.project_id
}

# ═══════════════════════════════════════════════════════════════
# WORKLOAD IDENTITY PROVIDER
# Defines HOW GitHub proves its identity to GCP
# Restricts to specific owner repo and branch
# ═══════════════════════════════════════════════════════════════
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  #checkov:skip=CKV_GCP_125: attribute_condition restricts to specific owner repo and branch
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"
  project                            = var.project_id

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }

  attribute_condition = "attribute.repository_owner=='${var.github_repository_owner}' && attribute.repository=='${var.github_repository}' && attribute.ref=='refs/heads/master'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# ═══════════════════════════════════════════════════════════════
# IAM BINDING — GitHub Actions → Service Account
# Allows GitHub Actions to impersonate the service account
# ═══════════════════════════════════════════════════════════════
resource "google_service_account_iam_member" "github_wif_binding" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_repository}"
}

# ═══════════════════════════════════════════════════════════════
# IAM — Artifact Registry Writer
# GitHub Actions pushes Docker images to registry
# ═══════════════════════════════════════════════════════════════
resource "google_project_iam_member" "github_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.repoAdmin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# ═══════════════════════════════════════════════════════════════
# IAM — Storage Object Admin
# GitHub Actions reads and writes Terraform state in GCS
# ═══════════════════════════════════════════════════════════════
resource "google_project_iam_member" "github_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# ═══════════════════════════════════════════════════════════════
# IAM — Compute Admin
# GitHub Actions manages GKE and compute resources via terraform
# More specific than roles/editor
# ═══════════════════════════════════════════════════════════════
resource "google_project_iam_member" "github_compute_admin" {
  project = var.project_id
  role    = "roles/compute.admin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# ═══════════════════════════════════════════════════════════════
# IAM — Container Admin
# GitHub Actions manages GKE cluster via terraform
# ═══════════════════════════════════════════════════════════════
resource "google_project_iam_member" "github_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# ═══════════════════════════════════════════════════════════════
# IAM — Cloud SQL Admin
# GitHub Actions manages Cloud SQL via terraform
# ═══════════════════════════════════════════════════════════════
resource "google_project_iam_member" "github_cloudsql_admin" {
  project = var.project_id
  role    = "roles/cloudsql.admin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# ═══════════════════════════════════════════════════════════════
# IAM — DNS Admin
# GitHub Actions manages Cloud DNS via terraform
# ═══════════════════════════════════════════════════════════════
resource "google_project_iam_member" "github_dns_admin" {
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# ═══════════════════════════════════════════════════════════════
# IAM — Service Account Admin
# GitHub Actions manages service accounts via terraform

# ═══════════════════════════════════════════════════════════════
# IAM — Service Networking Admin
# GitHub Actions manages VPC peering for Cloud SQL
# ═══════════════════════════════════════════════════════════════
resource "google_project_iam_member" "github_servicenetworking" {
  project = var.project_id
  role    = "roles/servicenetworking.networksAdmin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}
