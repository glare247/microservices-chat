# ═══════════════════════════════════════════════════════════════
# VARIABLES DEFINITION FILE
#
# PURPOSE:
#   Defines ALL input variables used in main.tf
#   No actual values here — only definitions
#   All values live in terraform.tfvars (git ignored)
#
# BEST PRACTICES APPLIED:
#   No default values — all must be explicitly set
#   No hardcoded values anywhere in this file
#   sensitive = true hides passwords from all output
#   Every variable has a clear description
# ═══════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════
# PROJECT
# Core GCP project configuration
# These tell Terraform WHERE to create resources
# ═══════════════════════════════════════════════════════════════

variable "project_id" {
  description = "GCP Project ID — unique identifier for your GCP project"
  type        = string
  # Value in tfvars: "microservices-chat"
  # Used in: provider, workload_identity, DNS, Artifact Registry
  # No default — must be explicitly provided
  # Prevents accidentally deploying to wrong project
}

variable "region" {
  description = "GCP Region — geographical location where all resources are created"
  type        = string
  # Value in tfvars: "us-central1"
  # Used in: all regional resources
  #   GKE cluster (regional = spans multiple zones)
  #   Cloud SQL (REGIONAL availability)
  #   Cloud Router and NAT Gateway
  #   Public and private subnets
  #   Artifact Registry
}

variable "zone" {
  description = "GCP Zone — specific datacenter within the region"
  type        = string
  # Value in tfvars: "us-central1-a"
  # Format: region + letter (a, b, c or f)
  # Used as reference zone
  # GKE nodes spread across zone-a AND zone-b
  # defined in node_locations in main.tf
}

# ═══════════════════════════════════════════════════════════════
# GKE CLUSTER
# Configuration for Google Kubernetes Engine
# Controls size performance and cost of cluster
# ═══════════════════════════════════════════════════════════════

variable "cluster_name" {
  description = "GKE Cluster name — used as prefix for ALL related resource names"
  type        = string
  # Value in tfvars: "chat-platform-cluster"
  # Creates consistent naming across all resources:
  #   chat-platform-cluster-vpc
  #   chat-platform-cluster-public-subnet
  #   chat-platform-cluster-private-subnet
  #   chat-platform-cluster-router
  #   chat-platform-cluster-nat
  #   chat-platform-cluster-node-pool
  #   chat-platform-cluster-dns-zone
  #   chat-platform-cluster-lb-ip
  #   chat-platform-cluster-registry (Artifact Registry)
}

variable "node_count" {
  description = "Number of GKE nodes per zone — total nodes = node_count x number of zones"
  type        = number
  # Value in tfvars: 1
  # 1 node per zone x 2 zones = 2 total nodes
  # Each node = 1 GCP Compute Engine VM
  # type = number not string — no quotes in tfvars
}

variable "machine_type" {
  description = "GKE node VM size — determines CPU and RAM per node"
  type        = string
  # Value in tfvars: "e2-medium"
  # e2-medium = 2 vCPU + 4GB RAM per node
  # Options:
  #   e2-micro       = 2 vCPU 1GB  (too small)
  #   e2-small       = 2 vCPU 2GB  (minimal)
  #   e2-medium      = 2 vCPU 4GB  (development)
  #   e2-standard-4  = 4 vCPU 16GB (production)
}

variable "min_node_count" {
  description = "Minimum GKE nodes per zone — autoscaler never goes below this"
  type        = number
  # Value in tfvars: 1
  # 1 per zone x 2 zones = 2 nodes minimum total
  # Cluster never becomes empty — always available
}

variable "max_node_count" {
  description = "Maximum GKE nodes per zone — autoscaler never exceeds this"
  type        = number
  # Value in tfvars: 3
  # 3 per zone x 2 zones = 6 nodes maximum total
  # Controls cost during unexpected traffic spikes
  # GKE adds nodes when pods cannot be scheduled
  # GKE removes nodes when underutilised
}

# ═══════════════════════════════════════════════════════════════
# NETWORKING
# IP address ranges for VPC subnets
# All ranges must be non-overlapping
#
# RANGE SIZES:
#   /24 = 254 usable IPs  (nodes — small range)
#   /16 = 65534 usable IPs (pods/services — large range)
# ═══════════════════════════════════════════════════════════════

variable "public_subnet_cidr" {
  description = "CIDR IP range for public subnet — contains Load Balancer NAT Gateway and Cloud Router"
  type        = string
  # Value in tfvars: "10.0.1.0/24"
  # 254 usable IPs for public-facing resources
  # Resources here CAN have public IP addresses
  # Faces the internet — receives traffic from chatms.store
}

variable "private_subnet_cidr" {
  description = "CIDR IP range for private subnet — contains GKE nodes Cloud SQL and NGINX Ingress"
  type        = string
  # Value in tfvars: "10.0.2.0/24"
  # 254 usable IPs for GKE worker node VMs
  # Resources here have NO public IP addresses
  # Cannot be reached directly from internet
  # GKE Node 1 (zone-a) = 10.0.2.10
  # GKE Node 2 (zone-b) = 10.0.2.11
}

variable "pods_cidr" {
  description = "CIDR IP range for Kubernetes pods — each pod gets unique IP from this range"
  type        = string
  # Value in tfvars: "10.1.0.0/16"
  # 65534 available IPs for pods
  # Pod IPs are TEMPORARY — change when pod restarts
  # chat_front pod = 10.1.0.5 (example)
  # chat_svc pod   = 10.1.0.6 (example)
  # chat_db pod    = 10.1.0.7 (example)
  # Large range needed — many pods run simultaneously
  # Secondary range on private_subnet
}

variable "services_cidr" {
  description = "CIDR IP range for Kubernetes services — stable endpoints that never change IP"
  type        = string
  # Value in tfvars: "10.2.0.0/16"
  # 65534 available IPs for K8s services
  # Service IPs are PERMANENT — never change
  # chat-front service = 10.2.0.10 (always)
  # chat-svc service   = 10.2.0.11 (always)
  # chat-db service    = 10.2.0.12 (always)
  # Pods use service IPs not pod IPs to communicate
  # This is why chat works even when pods restart
  # Secondary range on private_subnet
}

# ═══════════════════════════════════════════════════════════════
# DATABASE
# Cloud SQL PostgreSQL configuration
# Replaces SQLite from original microservices-chat repo
#
# SECURITY:
#   db_password has sensitive = true
#   Hidden in ALL terraform output and logs
#   Value only in terraform.tfvars (git ignored)
#   Injected into pods via Kubernetes Secret
# ═══════════════════════════════════════════════════════════════

variable "db_instance_name" {
  description = "Cloud SQL server instance name — the DATABASE SERVER not the database itself"
  type        = string
  # Value in tfvars: "chat-postgres-db"
  # This is the PostgreSQL SERVER name
  # One server can contain multiple databases
  # Analogy:
  #   db_instance_name = filing cabinet (server)
  #   db_name          = folder inside (database)
  # Must be unique within GCP project
}

variable "db_name" {
  description = "PostgreSQL database name — actual database inside the Cloud SQL instance"
  type        = string
  # Value in tfvars: "chatdb"
  # This is the DATABASE inside the server
  # Where all chat messages are stored
  # messages table lives inside chatdb
  # Connection: postgresql://...@IP/chatdb
}

variable "db_user" {
  description = "PostgreSQL username — used by chat_db pod to authenticate with Cloud SQL"
  type        = string
  # Value in tfvars: "chatuser"
  # Login username for the database
  # Injected into pods via Kubernetes Secret
  # Connection: postgresql://chatuser:...@IP/chatdb
}

variable "db_password" {
  description = "PostgreSQL password — credentials for chatuser to connect to Cloud SQL"
  type        = string
  sensitive   = true
  # sensitive = true means:
  #   Hidden in terraform plan → shows (sensitive value)
  #   Hidden in terraform apply → shows (sensitive value)
  #   Hidden in terraform output → use -raw flag
  #   Never appears in any logs
  # Value in tfvars: your secure password
  # Injected into pods via Kubernetes Secret
  # Never hardcoded in any application code
}

variable "db_tier" {
  description = "Cloud SQL machine tier — determines CPU and RAM for database server"
  type        = string
  # Value in tfvars: "db-f1-micro"
  # Options:
  #   db-f1-micro      = 1 vCPU 614MB  (cheapest — dev)
  #   db-g1-small      = 1 vCPU 1.7GB  (small prod)
  #   db-n1-standard-1 = 1 vCPU 3.75GB (standard prod)
  # db-f1-micro is correct for learning project
}

# ═══════════════════════════════════════════════════════════════
# DNS AND DOMAIN
# Cloud DNS configuration for chatms.store
#
# AFTER terraform apply — REQUIRED STEPS:
#   1. terraform output dns_nameservers
#   2. Copy all 4 Google nameservers
#   3. GoDaddy → chatms.store → Manage DNS
#   4. Change Nameservers → I'll use my own
#   5. Enter all 4 Google nameservers
#   6. Save → wait 24-48 hours propagation
#
# WHAT THIS CREATES:
#   Cloud DNS zone for chatms.store
#   A record: chatms.store     → static LB IP
#   A record: www.chatms.store → static LB IP
#   Static IP reserved for Load Balancer
# ═══════════════════════════════════════════════════════════════

variable "domain_name" {
  description = "Domain name for chat platform — purchased on GoDaddy"
  type        = string
  # Value in tfvars: "chatms.store"
  # Used to create:
  #   Cloud DNS zone: chatms.store
  #   A record: chatms.store → LB static IP
  #   A record: www.chatms.store → LB static IP
  # Users access platform at: https://chatms.store
  # SSL certificate issued to: chatms.store
  # After DNS propagation domain resolves to LB IP
}