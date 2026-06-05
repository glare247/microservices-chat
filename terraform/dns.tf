# ═══════════════════════════════════════════════════════════════
# DNS AND STATIC IP
# Cloud DNS zone and A records for all subdomains
# All subdomains point to NGINX Ingress Regional LB IP
# NGINX Ingress Controller routes traffic by hostname:
#   chatms.store         → chat-front (chat-app namespace)
#   www.chatms.store     → chat-front (chat-app namespace)
#   argocd.chatms.store  → argocd-server (argocd namespace)
#   grafana.chatms.store → grafana (monitoring namespace)
# ═══════════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────────
# OLD GCE GLOBAL IP
# REASON: Originally created for GCE Ingress Controller
#         No longer used after migrating to NGINX Ingress
#         Kept in state to avoid destroy/recreate cycle
#         DNS records no longer reference this IP
# ───────────────────────────────────────────────────────────────
resource "google_compute_global_address" "lb_ip" {
  name        = "${var.cluster_name}-lb-ip"
  description = "OLD: GCE Load Balancer IP — no longer used"
  project     = var.project_id
}

# ───────────────────────────────────────────────────────────────
# NGINX REGIONAL IP — DATA SOURCE (READ ONLY)
#
# WHY DATA SOURCE NOT RESOURCE:
#   This IP was created automatically by GKE
#   when NGINX Ingress Controller service
#   of type LoadBalancer was applied
#   Terraform did NOT create it
#   Terraform should NOT manage it
#   Terraform should only READ it
#
# DATA SOURCE = read existing GCP resource
# RESOURCE    = create new GCP resource
#
# Using data source prevents:
#   Terraform creating duplicate IP
#   DNS pointing to wrong new IP
#   Service disruption
# ───────────────────────────────────────────────────────────────
data "google_compute_address" "nginx_lb_ip" {
  name    = "nginx-lb-ip"
  region  = var.region
  project = var.project_id
}

# ───────────────────────────────────────────────────────────────
# DNS MANAGED ZONE
# Google Cloud DNS manages all records for chatms.store
# GoDaddy nameservers point to Google Cloud DNS
# ───────────────────────────────────────────────────────────────
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

# ───────────────────────────────────────────────────────────────
# DNS A RECORDS
# All 4 records point to nginx_lb_ip DATA SOURCE
# data.google_compute_address.nginx_lb_ip.address
# = reads existing IP 35.225.189.52 from GCP
# Does NOT create new IP
# ───────────────────────────────────────────────────────────────

# chatms.store → 35.225.189.52
resource "google_dns_record_set" "chat_a_record" {
  name         = "${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.chat_zone.name
  project      = var.project_id
  rrdatas      = [data.google_compute_address.nginx_lb_ip.address]
}

# www.chatms.store → 35.225.189.52
resource "google_dns_record_set" "chat_www_record" {
  name         = "www.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.chat_zone.name
  project      = var.project_id
  rrdatas      = [data.google_compute_address.nginx_lb_ip.address]
}

# argocd.chatms.store → 35.225.189.52
resource "google_dns_record_set" "argocd_a_record" {
  name         = "argocd.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.chat_zone.name
  project      = var.project_id
  rrdatas      = [data.google_compute_address.nginx_lb_ip.address]
}

# grafana.chatms.store → 35.225.189.52
resource "google_dns_record_set" "grafana_a_record" {
  name         = "grafana.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.chat_zone.name
  project      = var.project_id
  rrdatas      = [data.google_compute_address.nginx_lb_ip.address]
}
