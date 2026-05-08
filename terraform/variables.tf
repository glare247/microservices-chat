
# ═══════════════════════════════════════════════════════════════
# VARIABLES DEFINITION FILE
# ═══════════════════════════════════════════════════════════════

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

# tflint-ignore: terraform_unused_declarations
variable "zone" {
  description = "GCP Zone — reference zone within the region"
  type        = string
}

variable "cluster_name" {
  description = "GKE Cluster name — used as prefix for all resources"
  type        = string
}

# tflint-ignore: terraform_unused_declarations
variable "node_count" {
  description = "Number of GKE nodes per zone"
  type        = number
}

variable "machine_type" {
  description = "GKE node VM size"
  type        = string
}

variable "min_node_count" {
  description = "Minimum GKE nodes per zone for autoscaling"
  type        = number
}

variable "max_node_count" {
  description = "Maximum GKE nodes per zone for autoscaling"
  type        = number
}

variable "public_subnet_cidr" {
  description = "CIDR IP range for public subnet"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR IP range for private subnet"
  type        = string
}

variable "pods_cidr" {
  description = "CIDR IP range for Kubernetes pods"
  type        = string
}

variable "services_cidr" {
  description = "CIDR IP range for Kubernetes services"
  type        = string
}

variable "db_instance_name" {
  description = "Cloud SQL instance name"
  type        = string
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
}

variable "db_user" {
  description = "PostgreSQL username"
  type        = string
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "db_tier" {
  description = "Cloud SQL machine tier"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the chat platform"
  type        = string
}
