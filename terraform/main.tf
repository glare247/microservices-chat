
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
}

# ═══════════════════════════════════════════════════════════════
# PROVIDER
# ═══════════════════════════════════════════════════════════════
provider "google" {
  project = var.project_id
  region  = var.region
}

# ═══════════════════════════════════════════════════════════════
# DATA SOURCE — GCP DEFAULT SERVICE ACCOUNT
# ═══════════════════════════════════════════════════════════════
data "google_compute_default_service_account" "default" {
  project = var.project_id
}

# ═══════════════════════════════════════════════════════════════
# VPC NETWORK
# ═══════════════════════════════════════════════════════════════
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

# ═══════════════════════════════════════════════════════════════
# PUBLIC SUBNET — 10.0.1.0/24
# ═══════════════════════════════════════════════════════════════
resource "google_compute_subnetwork" "public_subnet" {
  name                     = "${var.cluster_name}-public-subnet"
  ip_cidr_range            = var.public_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  description              = "Public subnet for Load Balancer and NAT Gateway"
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ═══════════════════════════════════════════════════════════════
# PRIVATE SUBNET — 10.0.2.0/24
# private_ip_google_access = true
#   Artifact Registry pulls stay inside Google network
#   No NAT needed for GCP API calls
# ═══════════════════════════════════════════════════════════════
resource "google_compute_subnetwork" "private_subnet" {
  name                     = "${var.cluster_name}-private-subnet"
  ip_cidr_range            = var.private_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
  description              = "Private subnet for GKE nodes across 2 zones and Cloud SQL"

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ═══════════════════════════════════════════════════════════════
# FIREWALL — ALLOW INTERNAL TRAFFIC
# ═══════════════════════════════════════════════════════════════
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.cluster_name}-allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
}

# ═══════════════════════════════════════════════════════════════
# FIREWALL — ALLOW HTTP AND HTTPS
# ═══════════════════════════════════════════════════════════════
resource "google_compute_firewall" "allow_http_https" {
  #checkov:skip=CKV_GCP_106: Port 80 required for GCP load balancer health checks and HTTP to HTTPS redirect
  name    = "${var.cluster_name}-allow-http-https"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# ═══════════════════════════════════════════════════════════════
# CLOUD ROUTER
# ═══════════════════════════════════════════════════════════════
resource "google_compute_router" "router" {
  name        = "${var.cluster_name}-router"
  region      = var.region
  network     = google_compute_network.vpc.id
  description = "Cloud Router for NAT Gateway"
}

# ═══════════════════════════════════════════════════════════════
# NAT GATEWAY
# NEEDED FOR: pip install PyPI external APIs
# NOT NEEDED FOR: Artifact Registry Cloud SQL GCP APIs
#   (handled by private_ip_google_access)
# ═══════════════════════════════════════════════════════════════
resource "google_compute_router_nat" "nat" {
  name                               = "${var.cluster_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ═══════════════════════════════════════════════════════════════
# GKE CLUSTER — Private Multi-Zone Regional
# ═══════════════════════════════════════════════════════════════
#tfsec:ignore:google-container-enable-pod-security-policy
resource "google_container_cluster" "gke" {
  #checkov:skip=CKV_GCP_18: Public endpoint required for kubectl access in dev
  #checkov:skip=CKV_GCP_65: Google Groups RBAC requires Google Workspace
  #checkov:skip=CKV_GCP_66: Binary Authorization is enterprise feature
  #checkov:skip=CKV_GCP_69: Metadata server on node pool not cluster
  name     = var.cluster_name
  location = var.region

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.private_subnet.name

  node_locations = [
    "${var.region}-a",
    "${var.region}-b"
  ]

  remove_default_node_pool = true
  initial_node_count       = 1

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "all-for-dev"
    }
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  release_channel {
    channel = "REGULAR"
  }

  enable_intranode_visibility = true

  resource_labels = {
    env        = "dev"
    project    = var.cluster_name
    managed-by = "terraform"
  }

  deletion_protection = false
}

# ═══════════════════════════════════════════════════════════════
# GKE NODE POOL
# ═══════════════════════════════════════════════════════════════
resource "google_container_node_pool" "nodes" {
  name     = "${var.cluster_name}-node-pool"
  location = var.region
  cluster  = google_container_cluster.gke.name

  node_count = 1

  node_config {
    machine_type = var.machine_type
    disk_size_gb = 50
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      env        = "dev"
      project    = var.cluster_name
      managed-by = "terraform"
    }

    tags = ["gke-node", var.cluster_name]
  }

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# ═══════════════════════════════════════════════════════════════
# PRIVATE SERVICE ACCESS — IP RANGE
# ═══════════════════════════════════════════════════════════════
resource "google_compute_global_address" "private_service_range" {
  name          = "${var.cluster_name}-private-service-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

# ═══════════════════════════════════════════════════════════════
# PRIVATE SERVICE ACCESS — VPC CONNECTION
# deletion_policy ABANDON prevents destroy errors
# Cloud SQL must be deleted before connection
# ═══════════════════════════════════════════════════════════════
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]
  deletion_policy         = "ABANDON"

  depends_on = [google_compute_global_address.private_service_range]
}

# ═══════════════════════════════════════════════════════════════
# CLOUD SQL — PostgreSQL 15
# REGIONAL HA private IP SSL only
# ═══════════════════════════════════════════════════════════════
resource "google_sql_database_instance" "postgres" {
  #checkov:skip=CKV_GCP_79: POSTGRES_15 chosen stable version
  #checkov:skip=CKV_GCP_6: ssl_mode=ENCRYPTED_ONLY is stricter than require_ssl
  #checkov:skip=CKV_GCP_55: Conflicts with CKV_GCP_109 — ERROR satisfies 109
  name             = var.db_instance_name
  database_version = "POSTGRES_15"
  region           = var.region

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = var.db_tier
    availability_type = "REGIONAL"

    backup_configuration {
      enabled                        = true
      start_time                     = "02:00"
      point_in_time_recovery_enabled = true
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }

    database_flags {
      name  = "log_min_messages"
      value = "error"
    }

    database_flags {
      name  = "log_temp_files"
      value = "0"
    }

    database_flags {
      name  = "log_min_duration_statement"
      value = "-1"
    }

    database_flags {
      name  = "log_statement"
      value = "all"
    }

    database_flags {
      name  = "log_duration"
      value = "on"
    }

    database_flags {
      name  = "log_hostname"
      value = "on"
    }

    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }

    user_labels = {
      env        = "dev"
      project    = var.cluster_name
      managed-by = "terraform"
    }
  }

  deletion_protection = false
}

# ═══════════════════════════════════════════════════════════════
# DATABASE — chatdb
# ═══════════════════════════════════════════════════════════════
resource "google_sql_database" "chatdb" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
}

# ═══════════════════════════════════════════════════════════════
# DATABASE USER — chatuser
# ═══════════════════════════════════════════════════════════════
resource "google_sql_user" "chatuser" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}

# ═══════════════════════════════════════════════════════════════
# STATIC IP FOR LOAD BALANCER
# ═══════════════════════════════════════════════════════════════
resource "google_compute_global_address" "lb_ip" {
  name        = "${var.cluster_name}-lb-ip"
  description = "Static IP for Cloud Load Balancer — chatms.store DNS"
  project     = var.project_id
}

# ═══════════════════════════════════════════════════════════════
# CLOUD DNS MANAGED ZONE
# DNSSEC enabled for domain security
# ═══════════════════════════════════════════════════════════════
resource "google_dns_managed_zone" "chat_zone" {
  name        = "${var.cluster_name}-dns-zone"
  dns_name    = "${var.domain_name}."
  description = "DNS zone for ${var.domain_name}"
  project     = var.project_id
  visibility  = "public"

  dnssec_config {
    state = "on"
  }
}

# ═══════════════════════════════════════════════════════════════
# DNS A RECORDS
# All subdomains point to same Load Balancer IP
# NGINX Ingress routes by hostname
# ═══════════════════════════════════════════════════════════════
resource "google_dns_record_set" "chat_a_record" {
  name         = "${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.chat_zone.name
  project      = var.project_id
  rrdatas      = [google_compute_global_address.lb_ip.address]
}

resource "google_dns_record_set" "chat_www_record" {
  name         = "www.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.chat_zone.name
  project      = var.project_id
  rrdatas      = [google_compute_global_address.lb_ip.address]
}

resource "google_dns_record_set" "argocd_a_record" {
  name         = "argocd.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.chat_zone.name
  project      = var.project_id
  rrdatas      = [google_compute_global_address.lb_ip.address]
}

resource "google_dns_record_set" "grafana_a_record" {
  name         = "grafana.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.chat_zone.name
  project      = var.project_id
  rrdatas      = [google_compute_global_address.lb_ip.address]
}

# ═══════════════════════════════════════════════════════════════
# GOOGLE ARTIFACT REGISTRY — Private Docker Registry
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

# ═══════════════════════════════════════════════════════════════
# IAM — GKE NODES PULL IMAGES (reader role)
# ═══════════════════════════════════════════════════════════════
resource "google_artifact_registry_repository_iam_member" "gke_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.chat_registry.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

# ═══════════════════════════════════════════════════════════════
# IAM — GITHUB ACTIONS PUSH IMAGES (writer role)
# ═══════════════════════════════════════════════════════════════
resource "google_artifact_registry_repository_iam_member" "github_writer" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.chat_registry.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:github-actions@microservices-chat.iam.gserviceaccount.com"
}

