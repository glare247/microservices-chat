# ═══════════════════════════════════════════════════════════════
# OUTPUTS DEFINITION FILE
#
# PURPOSE:
#   Displays important values after terraform apply
#   Acts as a summary of everything created
#
# HOW TO VIEW:
#   All outputs:      terraform output
#   Specific output:  terraform output gke_cluster_name
#   Sensitive output: terraform output -raw database_url
# ═══════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════
# GKE OUTPUTS
# Information about your Kubernetes cluster
# Used when connecting kubectl and deploying applications
# ═══════════════════════════════════════════════════════════════

output "gke_cluster_name" {
  description = "GKE Cluster name — used in kubectl and ArgoCD setup"
  value       = google_container_cluster.gke.name
  # Example: "chat-platform-cluster"
}

output "gke_cluster_region" {
  description = "GKE Cluster region — geographical location of cluster"
  value       = var.region
  # Example: "us-central1"
}

output "gke_cluster_endpoint" {
  description = "GKE Cluster API server endpoint — IP of Kubernetes control plane"
  value       = google_container_cluster.gke.endpoint
  sensitive   = true
  # To view: terraform output -raw gke_cluster_endpoint
  # Used by kubectl and ArgoCD to communicate with cluster
}

output "kubectl_connect_command" {
  description = "Run this command to connect kubectl to your GKE cluster"
  value       = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.project_id}"
  # Copy and run in terminal after terraform apply
  # Configures kubectl to talk to your GKE cluster
  # Then verify with: kubectl get nodes
}

# ═══════════════════════════════════════════════════════════════
# NETWORKING OUTPUTS
# Information about VPC subnets NAT and routing
# Used to verify infrastructure matches architecture diagram
# ═══════════════════════════════════════════════════════════════

output "public_subnet_name" {
  description = "Public subnet — contains Cloud Load Balancer NAT Gateway and Cloud Router"
  value       = google_compute_subnetwork.public_subnet.name
  # Example: "chat-platform-cluster-public-subnet"
  # CIDR: 10.0.1.0/24
  # Faces the internet
}

output "private_subnet_name" {
  description = "Private subnet — contains GKE nodes Cloud SQL NGINX Ingress and all pods"
  value       = google_compute_subnetwork.private_subnet.name
  # Example: "chat-platform-cluster-private-subnet"
  # CIDR: 10.0.2.0/24
  # No direct internet access
  # private_ip_google_access = true allows
  # Artifact Registry and GCP API access
  # without internet or NAT
}

output "nat_gateway_name" {
  description = "NAT Gateway — handles outbound internet for private pods (pip install external APIs)"
  value       = google_compute_router_nat.nat.name
  # Example: "chat-platform-cluster-nat"
  # NOTE: Artifact Registry image pulls do NOT use NAT
  # They use private_ip_google_access instead
  # NAT handles non-Google public internet traffic only
}

output "cloud_router_name" {
  description = "Cloud Router — prerequisite for NAT Gateway handles outbound routing"
  value       = google_compute_router.router.name
  # Example: "chat-platform-cluster-router"
}

# ═══════════════════════════════════════════════════════════════
# DATABASE OUTPUTS
# Connection details for Cloud SQL PostgreSQL
# SAVE THESE — needed in Phase 5 for Kubernetes Secrets
# ═══════════════════════════════════════════════════════════════

output "cloud_sql_private_ip" {
  description = "Cloud SQL private IP — use in Kubernetes Secret for chat_db pod connection"
  value       = google_sql_database_instance.postgres.private_ip_address
  # Example: "10.30.0.2"
  # Private IP — only accessible inside VPC
  # chat_db pod connects: postgresql://...@THIS_IP:5432/chatdb
  # Save this — needed in Phase 5
}

output "cloud_sql_connection_name" {
  description = "Cloud SQL connection name — used if connecting via Cloud SQL Auth Proxy"
  value       = google_sql_database_instance.postgres.connection_name
  # Example: "microservices-chat:us-central1:chat-postgres-db"
  # Format: project:region:instance-name
}

output "db_name" {
  description = "Database name — PostgreSQL database where chat messages are stored"
  value       = var.db_name
  # Example: "chatdb"
  # Used in Kubernetes Secret Phase 5
}

output "db_user" {
  description = "Database username — used by chat_db pod to authenticate with Cloud SQL"
  value       = var.db_user
  # Example: "chatuser"
  # Used in Kubernetes Secret Phase 5
}

output "database_url" {
  description = "Complete DATABASE_URL — copy into Kubernetes Secret in Phase 5"
  value       = "postgresql+asyncpg://${var.db_user}:${var.db_password}@${google_sql_database_instance.postgres.private_ip_address}:5432/${var.db_name}"
  sensitive   = true
  # To view: terraform output -raw database_url
  # Example: postgresql+asyncpg://chatuser:pass@10.30.0.2:5432/chatdb
  #
  # FORMAT:
  #   postgresql+asyncpg:// = async PostgreSQL driver
  #   chatuser              = db_user variable
  #   password              = db_password (sensitive)
  #   10.30.0.2             = Cloud SQL private IP
  #   5432                  = PostgreSQL port
  #   chatdb                = db_name variable
  #
  # USE IN PHASE 5:
  #   kubectl create secret generic chat-db-secret \
  #     --from-literal=DATABASE_URL="$(terraform output -raw database_url)"
}

# ═══════════════════════════════════════════════════════════════
# DNS AND DOMAIN OUTPUTS
# Information about Cloud DNS and chatms.store domain
#
# AFTER terraform apply — IMMEDIATE ACTION REQUIRED:
#   1. terraform output dns_nameservers
#   2. Copy all 4 nameservers
#   3. GoDaddy → chatms.store → Manage DNS
#   4. Change Nameservers → I'll use my own
#   5. Enter all 4 Google nameservers
#   6. Save → wait 24-48 hours propagation
# ═══════════════════════════════════════════════════════════════

output "static_lb_ip" {
  description = "Static IP for Cloud Load Balancer — DNS A record points to this permanently"
  value       = google_compute_global_address.lb_ip.address
  # Example: "34.XX.XX.XX"
  # This IP never changes even if LB is recreated
  # chatms.store A record → this IP
  # Used in Kubernetes Ingress annotation Phase 5:
  # kubernetes.io/ingress.global-static-ip-name: chat-platform-cluster-lb-ip
}

output "dns_nameservers" {
  description = "Google Cloud DNS nameservers — add ALL 4 to GoDaddy nameserver settings"
  value       = google_dns_managed_zone.chat_zone.name_servers
  # Example:
  # [
  #   "ns-cloud-b1.googledomains.com.",
  #   "ns-cloud-b2.googledomains.com.",
  #   "ns-cloud-b3.googledomains.com.",
  #   "ns-cloud-b4.googledomains.com.",
  # ]
  # Add ALL 4 to GoDaddy immediately after terraform apply
  # DNS propagation takes 24-48 hours worldwide
}

output "app_url" {
  description = "Chat platform URL — accessible after DNS propagation and SSL certificate issued"
  value       = "https://${var.domain_name}"
  # Example: "https://chatms.store"
  # Share with users after:
  #   GoDaddy nameservers updated     ✅
  #   DNS propagated worldwide        ✅ 24-48 hours
  #   SSL certificate issued          ✅ 10-15 minutes
  #   All pods running in GKE         ✅
}

output "www_app_url" {
  description = "Chat platform URL with www — both chatms.store and www.chatms.store work"
  value       = "https://www.${var.domain_name}"
  # Example: "https://www.chatms.store"
  # Users who type www prefix reach the same app
}

# ═══════════════════════════════════════════════════════════════
# ARTIFACT REGISTRY OUTPUTS
# Private Docker registry information
# Used in CI workflow and Kubernetes manifests
# ═══════════════════════════════════════════════════════════════

output "artifact_registry_url" {
  description = "Artifact Registry URL — use in CI workflow and K8s deployment manifests"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.cluster_name}-registry"
  # Example:
  # "us-central1-docker.pkg.dev/microservices-chat/chat-platform-cluster-registry"
  #
  # FULL IMAGE PATHS:
  # us-central1-docker.pkg.dev/microservices-chat/chat-platform-cluster-registry/chat-front:SHA
  # us-central1-docker.pkg.dev/microservices-chat/chat-platform-cluster-registry/chat-svc:SHA
  # us-central1-docker.pkg.dev/microservices-chat/chat-platform-cluster-registry/chat-db:SHA
  #
  # Used in:
  #   CI workflow  → docker push to this URL
  #   K8s manifests → image: this-url/chat-front:SHA
}

output "artifact_registry_chat_front" {
  description = "Full image path for chat_front — use in K8s deployment manifest"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.cluster_name}-registry/chat-front"
  # Add :SHA tag when using in deployment.yaml
  # Example: image: us-central1-docker.pkg.dev/microservices-chat/
  #          chat-platform-cluster-registry/chat-front:abc123
}

output "artifact_registry_chat_svc" {
  description = "Full image path for chat_svc — use in K8s deployment manifest"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.cluster_name}-registry/chat-svc"
}

output "artifact_registry_chat_db" {
  description = "Full image path for chat_db — use in K8s deployment manifest"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.cluster_name}-registry/chat-db"
}