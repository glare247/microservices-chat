# ═══════════════════════════════════════════════════════════════
# GKE CLUSTER — Private Multi-Zone Regional
# REGIONAL HA private nodes workload identity
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
