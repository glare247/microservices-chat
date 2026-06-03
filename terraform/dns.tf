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
# OLD GCE GLOBAL IP (kept in state but no longer used)
# REASON: Originally used for GCE Ingress Controller
#         Migrated to NGINX Ingress which uses Regional IP
#         Cannot delete until removed from terraform state
# ───────────────────────────────────────────────────────────────
resource "google_compute_global_address" "lb_ip" {
  name        = "${var.cluster_name}-lb-ip"
  description = "OLD: Static IP for GCE Load Balancer — no longer used. Replaced by nginx_lb_ip"
  project     = var.project_id
}

# ───────────────────────────────────────────────────────────────
# NEW NGINX REGIONAL IP
# REASON: NGINX Ingress Controller creates a Regional LB
#         Regional LB cannot use Global IP
#         This regional IP is what all DNS records point to
#         IP: 35.225.189.52
# ───────────────────────────────────────────────────────────────
resource "google_compute_address" "nginx_lb_ip" {
  name         = "${var.cluster_name}-nginx-lb-ip"
  description  = "Regional static IP for NGINX Ingress Load Balancer — all DNS records point here"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
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
# CHANGED: All 4 records now point to nginx_lb_ip
#          instead of old lb_ip (GCE Global IP)
# ───────────────────────────────────────────────────────────────

# chatms.store → 35.225.189.52
resource "google_dns_record_set" "chat_a_record" {
  name         = "${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.chat_zone.name
  project      = var.project_id
  # CHANGED: lb_ip → nginx_lb_ip
  rrdatas      = [google_compute_address.nginx_lb_ip.address]
}

# www.chatms.store → 35.225.189.52
resource "google_dns_record_set" "chat_www_record" {
  name         = "www.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.chat_zone.name
  project      = var.project_id
  # CHANGED: lb_ip → nginx_lb_ip
  rrdatas      = [google_compute_address.nginx_lb_ip.address]
}

# argocd.chatms.store → 35.225.189.52
resource "google_dns_record_set" "argocd_a_record" {
  name         = "argocd.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.chat_zone.name
  project      = var.project_id
  # CHANGED: lb_ip → nginx_lb_ip
  rrdatas      = [google_compute_address.nginx_lb_ip.address]
}

# grafana.chatms.store → 35.225.189.52
resource "google_dns_record_set" "grafana_a_record" {
  name         = "grafana.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.chat_zone.name
  project      = var.project_id
  # CHANGED: lb_ip → nginx_lb_ip
  rrdatas      = [google_compute_address.nginx_lb_ip.address]
}
