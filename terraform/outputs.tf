output "gke_cluster_name" {
  description = "GKE Cluster name — used in kubectl and ArgoCD setup"
  value       = google_container_cluster.gke.name
}

output "gke_cluster_region" {
  description = "GKE Cluster region — geographical location of cluster"
  value       = var.region
}

output "gke_cluster_endpoint" {
  description = "GKE Cluster API server endpoint — IP of Kubernetes control plane"
  value       = google_container_cluster.gke.endpoint
  sensitive   = true
}

output "kubectl_connect_command" {
  description = "Run this command to connect kubectl to your GKE cluster"
  value       = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.project_id}"
}

output "public_subnet_name" {
  description = "Public subnet — contains Cloud Load Balancer, NAT Gateway and Cloud Router"
  value       = google_compute_subnetwork.public_subnet.name
}

output "private_subnet_name" {
  description = "Private subnet — contains GKE nodes, Cloud SQL, NGINX Ingress and all pods"
  value       = google_compute_subnetwork.private_subnet.name
}

output "nat_gateway_name" {
  description = "NAT Gateway — allows private GKE nodes to pull Docker images from Docker Hub"
  value       = google_compute_router_nat.nat.name
}

output "cloud_router_name" {
  description = "Cloud Router — prerequisite for NAT Gateway, handles outbound routing"
  value       = google_compute_router.router.name
}

output "cloud_sql_private_ip" {
  description = "Cloud SQL private IP — use this in Kubernetes Secret for chat_db connection"
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "cloud_sql_connection_name" {
  description = "Cloud SQL connection name — used if connecting via Cloud SQL Auth Proxy"
  value       = google_sql_database_instance.postgres.connection_name
}

output "db_name" {
  description = "Database name — PostgreSQL database where chat messages are stored"
  value       = var.db_name
}

output "db_user" {
  description = "Database username — used by chat_db pod to authenticate with Cloud SQL"
  value       = var.db_user
}

output "database_url" {
  description = "Complete DATABASE_URL — copy into Kubernetes Secret in Phase 5"
  value       = "postgresql+asyncpg://${var.db_user}:${var.db_password}@${google_sql_database_instance.postgres.private_ip_address}:5432/${var.db_name}"
  sensitive   = true
}

output "static_lb_ip" {
  description = "Static IP for Cloud Load Balancer — DNS A record points to this IP"
  value       = google_compute_global_address.lb_ip.address
}

output "dns_nameservers" {
  description = "Google Cloud DNS nameservers — add ALL 4 to GoDaddy nameserver settings"
  value       = google_dns_managed_zone.chat_zone.name_servers
}

output "app_url" {
  description = "Chat platform URL — accessible after DNS propagation and SSL certificate issued"
  value       = "https://${var.domain_name}"
}

output "www_app_url" {
  description = "Chat platform URL with www — both chatms.store and www.chatms.store work"
  value       = "https://www.${var.domain_name}"
}