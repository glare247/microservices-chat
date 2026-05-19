# ═══════════════════════════════════════════════════════════════
# IAM — GitHub Actions Workload Identity Federation
# Keyless auth for CI pipeline — no long-lived credentials
# Pool: github-pool / Provider: github-provider
# Service account: github-actions@microservices-chat.iam.gserviceaccount.com

# ═══════════════════════════════════════════════════════════════

resource "google_service_account" "github_actions" {
  account_id   = "github-actions"
  display_name = "GitHub Actions CI"
  description  = "Used by GitHub Actions CI pipeline for Artifact Registry push"
  project      = var.project_id
}

resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
  description               = "WIF pool for GitHub Actions CI pipeline"
  project                   = var.project_id
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  #checkov:skip=CKV_GCP_125: condition restricts to specific owner and repo via variables — checkov cannot resolve tfvars in CI
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"
  project                            = var.project_id

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  attribute_condition = "attribute.repository_owner=='${var.github_repository_owner}' && attribute.repository=='${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_wif_binding" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_repository}"
}
