# ═══════════════════════════════════════════════════════════════
# TERRAFORM CONFIGURATION
# ═══════════════════════════════════════════════════════════════
terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# ═══════════════════════════════════════════════════════════════
# PROVIDER
# Connects Terraform to GCP
# Uses gcloud Application Default Credentials
# No hardcoded keys anywhere
# ═══════════════════════════════════════════════════════════════
provider "google" {
  project = var.project_id
  region  = var.region
}

# ═══════════════════════════════════════════════════════════════
# DATA SOURCE — GCP DEFAULT SERVICE ACCOUNT
# Gets the default compute service account email
# Used by GKE nodes to pull images from Artifact Registry
# via private_ip_google_access — no NAT needed
# ═══════════════════════════════════════════════════════════════
data "google_compute_default_service_account" "default" {
  project = var.project_id
}

# ═══════════════════════════════════════════════════════════════
# VPC NETWORK
# Main private network container for all resources
# auto_create_subnetworks = false gives full control
# We create our own public and private subnets
# ═══════════════════════════════════════════════════════════════
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

# ═══════════════════════════════════════════════════════════════
# PUBLIC SUBNET — 10.0.1.0/24
# Internet facing subnet
# Resources here CAN have public IP addresses
#
# CONTAINS:
#   Cloud Load Balancer — receives user traffic from chatms.store
#   NAT Gateway         — outbound internet for pods
#   Cloud Router        — routes outbound traffic
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
# Secure internal subnet — NO direct internet access
# Resources here have ONLY private IP addresses
#
# CONTAINS:
#   GKE nodes    — runs all microservice pods
#   NGINX Ingress — routes traffic to pods
#   Cloud SQL    — PostgreSQL database
#
# private_ip_google_access = true
#   Allows private nodes to reach Google APIs directly:
#     Artifact Registry — image pulls (no NAT needed)
#     Cloud SQL API
#     GCP Logging API
#     GCP Monitoring API
#   Traffic stays INSIDE Google network
#   Does NOT go through internet or NAT
#
# THREE IP RANGES:
#   Main:     10.0.2.0/24  — GKE node VMs
#   Pods:     10.1.0.0/16  — pod IPs (temporary)
#   Services: 10.2.0.0/16  — service IPs (permanent)
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
# Allows ALL traffic between resources inside the VPC
#
# REQUIRED FOR:
#   chat_front → chat_svc  (Socket.IO messages)
#   chat_svc   → chat_db   (HTTP API calls)
#   chat_db    → Cloud SQL (PostgreSQL port 5432)
#   GKE nodes  → GKE nodes (cluster communication)
#   Prometheus → all pods  (metrics scraping)
#   Promtail   → Loki      (log shipping)
#
# source_ranges 10.0.0.0/8 covers ALL internal ranges:
#   10.0.1.x (public subnet)
#   10.0.2.x (private subnet)
#   10.1.0.x (pods)
#   10.2.0.x (services)
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
# Opens ports 80 and 443 to the internet
# How users access chatms.store
# All other ports blocked by default
# Minimum attack surface — security best practice
# ═══════════════════════════════════════════════════════════════
resource "google_compute_firewall" "allow_http_https" {
  #checkov:skip=CKV_GCP_106: Port 80 required for GCP load balancer health checks and HTTP→HTTPS redirect
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
# Virtual router required for NAT Gateway
# Cannot create NAT Gateway without Cloud Router
# ═══════════════════════════════════════════════════════════════
resource "google_compute_router" "router" {
  name        = "${var.cluster_name}-router"
  region      = var.region
  network     = google_compute_network.vpc.id
  description = "Cloud Router for NAT Gateway"
}

# ═══════════════════════════════════════════════════════════════
# NAT GATEWAY
# Provides OUTBOUND internet for private pods
# OUTBOUND ONLY — internet cannot initiate inbound
#
# NEEDED FOR:
#   pip install → PyPI (public internet)
#   Any future external API calls from pods
#
# NOT NEEDED FOR (private_ip_google_access handles these):
#   Artifact Registry — stays inside Google network
#   Cloud SQL         — private VPC connection
#   GCP Logging       — Google internal network
#   GCP Monitoring    — Google internal network
#
# WHY KEEP IT:
#   Standard best practice for private subnets
#   Cheap insurance for future external calls
#   pip install needs it during pod startup
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
# Runs all 3 microservice pods inside private subnet
#
# KEY DESIGN DECISIONS:
#   REGIONAL          — control plane replicated across zones
#   PRIVATE nodes     — no public IPs on worker VMs
#   TWO ZONES         — zone-a AND zone-b (high availability)
#   WORKLOAD IDENTITY — secure GCP auth without keys
#
# HIGH AVAILABILITY:
#   If zone-a fails zone-b keeps serving traffic
#   No single point of failure
# ═══════════════════════════════════════════════════════════════
resource "google_container_cluster" "gke" {
  #checkov:skip=CKV_GCP_18: Public endpoint required for kubectl access in dev — restrict to VPN IP in production
  #checkov:skip=CKV_GCP_65: Google Groups for RBAC requires Google Workspace — not available in dev project
  #checkov:skip=CKV_GCP_66: Binary Authorization is an enterprise feature — out of scope for dev environment
  #checkov:skip=CKV_GCP_69: Metadata server configured on node pool resource, not cluster resource
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

  pod_security_policy_config {
    enabled = true
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
# Actual VM worker nodes that run your pods
#
# node_count = 1 PER ZONE
# 2 zones = 2 nodes total minimum
#
# AUTOSCALING:
#   min = 1 per zone → 2 nodes minimum
#   max = 3 per zone → 6 nodes maximum
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

    labels = {
      env        = "dev"
      project    = var.cluster_name
      managed-by = "terraform"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
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
# Reserves a private IP range for Google managed services
# Required for Cloud SQL to receive a private IP
# Without this Cloud SQL can only get a public IP
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
# Creates VPC peering with Google service network
# Gives Cloud SQL a private IP inside our VPC
# chat_db connects to Cloud SQL via private IP
# No public internet exposure for database
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
# Managed database replacing SQLite from original repo
#
# UPGRADES FROM ORIGINAL REPO:
#   SQLite     → PostgreSQL 15  (production grade)
#   No backup  → Auto backup    (data protection)
#   ZONAL      → REGIONAL HA    (high availability)
#   Public IP  → Private IP     (security)
#   No SSL     → SSL only       (encryption in transit)
#
# REGIONAL = primary zone-a + standby zone-b
#   Auto-failover if zone-a fails
#   Zero downtime maintenance
# ═══════════════════════════════════════════════════════════════
resource "google_sql_database_instance" "postgres" {
  #checkov:skip=CKV_GCP_79: POSTGRES_15 is our chosen stable version; upgrading to 16 requires testing
  #checkov:skip=CKV_GCP_6: ssl_mode=ENCRYPTED_ONLY is stricter than require_ssl — checkov does not recognise the newer attribute
  #checkov:skip=CKV_GCP_55: CKV_GCP_55 conflicts with CKV_GCP_109 in checkov 3.2.527 — ERROR satisfies CKV_GCP_109 (stricter) but incorrectly fails CKV_GCP_55
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
# Actual PostgreSQL database inside the Cloud SQL server
# Where all chat messages are stored permanently
# ═══════════════════════════════════════════════════════════════
resource "google_sql_database" "chatdb" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
}

# ═══════════════════════════════════════════════════════════════
# DATABASE USER — chatuser
# Login credentials for chat_db pod
# Password injected via Kubernetes Secret
# Never hardcoded in application code
# ═══════════════════════════════════════════════════════════════
resource "google_sql_user" "chatuser" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}

# ═══════════════════════════════════════════════════════════════
# STATIC IP FOR LOAD BALANCER
# Permanent public IP for Cloud Load Balancer
# DNS A record always points to this IP
# Even if LB recreated IP stays the same
# Without static IP DNS breaks when LB IP changes
# ═══════════════════════════════════════════════════════════════
resource "google_compute_global_address" "lb_ip" {
  name        = "${var.cluster_name}-lb-ip"
  description = "Static IP for Cloud Load Balancer — chatms.store DNS"
  project     = var.project_id
}

# ═══════════════════════════════════════════════════════════════
# CLOUD DNS MANAGED ZONE
# GCP equivalent of AWS Route 53
# Manages all DNS records for chatms.store
#
# AFTER terraform apply:
#   terraform output dns_nameservers
#   Go to GoDaddy → chatms.store → Manage DNS
#   Change to Google Cloud DNS nameservers
#   Wait 24-48 hours for DNS propagation
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
# DNS A RECORD — ROOT DOMAIN
# Points chatms.store to Load Balancer static IP
# TTL 300 = changes propagate within 5 minutes
# ═══════════════════════════════════════════════════════════════
resource "google_dns_record_set" "chat_a_record" {
  name         = "${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.chat_zone.name
  project      = var.project_id
  rrdatas      = [google_compute_global_address.lb_ip.address]
}

# ═══════════════════════════════════════════════════════════════
# DNS A RECORD — WWW SUBDOMAIN
# Points www.chatms.store to same Load Balancer IP
# Users who type www. still reach the app
# ═══════════════════════════════════════════════════════════════
resource "google_dns_record_set" "chat_www_record" {
  name         = "www.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.chat_zone.name
  project      = var.project_id
  rrdatas      = [google_compute_global_address.lb_ip.address]
}

# ═══════════════════════════════════════════════════════════════
# GOOGLE ARTIFACT REGISTRY — Private Docker Registry
# Replaces public Docker Hub
#
# WHY PRIVATE REGISTRY OVER DOCKER HUB:
#   Private    — only GCP account can access images
#   Faster     — GKE pulls via private_ip_google_access
#                stays inside Google network
#                NO NAT needed for image pulls
#   Secure     — integrated with Workload Identity
#   No limits  — no Docker Hub rate limiting
#   Scanning   — built-in vulnerability scanning
#
# HOW GKE PULLS IMAGES WITHOUT NAT:
#   private_ip_google_access = true on private subnet
#   GKE reaches Artifact Registry via Google internal network
#   Traffic never leaves Google infrastructure
#   No internet required — no NAT required
#
# IMAGE PATH FORMAT:
#   us-central1-docker.pkg.dev/
#   microservices-chat/
#   chat-platform-cluster-registry/
#   chat-front:SHA
# ═══════════════════════════════════════════════════════════════
resource "google_artifact_registry_repository" "chat_registry" {
  #checkov:skip=CKV_GCP_84: CSEK requires customer-managed KMS keys — out of scope for dev; Google-managed encryption is sufficient
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
# IAM — ALLOW GKE NODES TO PULL IMAGES
# Grants GKE default service account
# reader permission on Artifact Registry
#
# reader role — pull images ONLY
# Cannot push delete or manage repository
# Least privilege principle applied
#
# Authentication flow:
#   GKE node → Workload Identity → IAM check
#   IAM confirms reader role → image pulled
#   No keys or credentials stored anywhere
# ═══════════════════════════════════════════════════════════════
resource "google_artifact_registry_repository_iam_member" "gke_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.chat_registry.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

# ═══════════════════════════════════════════════════════════════
# IAM — ALLOW GITHUB ACTIONS TO PUSH IMAGES
# Grants GitHub Actions service account
# writer permission on Artifact Registry
#
# writer role — push and pull images
# Cannot delete images or manage repository
# Least privilege principle applied
#
# Authentication flow:
#   GitHub Actions → Workload Identity Federation
#   → IAM check → writer role confirmed
#   → image pushed to registry
#   No JSON keys stored anywhere
# ═══════════════════════════════════════════════════════════════
resource "google_artifact_registry_repository_iam_member" "github_writer" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.chat_registry.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:github-actions@microservices-chat.iam.gserviceaccount.com"
}
# ═══════════════════════════════════════════════════════════════
# DNS A RECORD — ARGOCD SUBDOMAIN
# Points argocd.chatms.store to same Load Balancer IP
# ArgoCD accessible at https://argocd.chatms.store
# ═══════════════════════════════════════════════════════════════
resource "google_dns_record_set" "argocd_a_record" {
  name         = "argocd.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.chat_zone.name
  project      = var.project_id
  rrdatas      = [google_compute_global_address.lb_ip.address]
}


# ═══════════════════════════════════════════════════════════════
# DNS A RECORD — GRAFANA SUBDOMAIN
# Points grafana.chatms.store to same Load Balancer IP
# Grafana accessible at https://grafana.chatms.store
# Adding now so SSL cert covers all subdomains
# ═══════════════════════════════════════════════════════════════
resource "google_dns_record_set" "grafana_a_record" {
  name         = "grafana.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.chat_zone.name
  project      = var.project_id
  rrdatas      = [google_compute_global_address.lb_ip.address]
}
