# ═══════════════════════════════════════════════════════════════
# DNS AND STATIC IP
# Cloud DNS zone and A records for all subdomains
# All subdomains point to same Load Balancer IP
# NGINX Ingress routes by hostname
# ═══════════════════════════════════════════════════════════════

resource "google_compute_global_address" "lb_ip" {
  name        = "${var.cluster_name}-lb-ip"
  description = "Static IP for Cloud Load Balancer — chatms.store DNS"
  project     = var.project_id
}

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
