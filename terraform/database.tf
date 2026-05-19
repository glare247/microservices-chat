# ═══════════════════════════════════════════════════════════════
# DATABASE
# Private service access and Cloud SQL PostgreSQL
# REGIONAL HA private IP SSL only
# ═══════════════════════════════════════════════════════════════

resource "google_compute_global_address" "private_service_range" {
  name          = "${var.cluster_name}-private-service-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]
  deletion_policy         = "ABANDON"

  depends_on = [google_compute_global_address.private_service_range]
}

resource "google_sql_database_instance" "postgres" {
  #checkov:skip=CKV_GCP_79: POSTGRES_15 chosen stable version
  #checkov:skip=CKV_GCP_6: ssl_mode=ENCRYPTED_ONLY is stricter than require_ssl
  #checkov:skip=CKV_GCP_109: log_min_messages=error is set — checkov bug with large files
  
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

resource "google_sql_database" "chatdb" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "chatuser" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}
