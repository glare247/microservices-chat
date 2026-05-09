# ═══════════════════════════════════════════════════════════════
# ARTIFACT REGISTRY
# Private Docker registry — replaces Docker Hub
# GKE pulls via private_ip_google_access — no NAT needed
# ═══════════════════════════════════════════════════════════════

resource "google_artifact_registry_repository" "chat_registry" {
  #checkov:skip=CKV_GCP_84: CSEK out of scope for dev — Google-managed encryption sufficient
  project       = var.project_id
  location      = var.region
  repository_id = "${var.cluster_name}-registry"
  description   = "Private Docker registry for chat platform microservices"
  format        = "DOCKER"

  labels = {
    env        = "dev"
    project    = var.cluster_name
    managed-by = "terraform"
  }
}

resource "google_artifact_registry_repository_iam_member" "gke_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.chat_registry.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_artifact_registry_repository_iam_member" "github_writer" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.chat_registry.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:github-actions@microservices-chat.iam.gserviceaccount.com"
}
