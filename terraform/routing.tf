# ═══════════════════════════════════════════════════════════════
# ROUTING
# Cloud Router and NAT Gateway
# NAT needed for: pip install PyPI external APIs
# NOT needed for: Artifact Registry Cloud SQL GCP APIs
# ═══════════════════════════════════════════════════════════════

resource "google_compute_router" "router" {
  name        = "${var.cluster_name}-router"
  region      = var.region
  network     = google_compute_network.vpc.id
  description = "Cloud Router for NAT Gateway"
}

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
