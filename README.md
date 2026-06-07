# 🚀 Production Grade Microservices Chat Platform on GCP/GKE

A fully production-grade cloud-native chat application deployed on Google Kubernetes Engine (GKE) with complete CI/CD, GitOps, SSL, monitoring and observability. Built as a DevOps portfolio project demonstrating real-world skills used in enterprise environments.

---

## 🌐 Live URLs

| Service | URL | Status |
|---------|-----|--------|
| Chat App | https://chatms.store | ✅ Live |
| ArgoCD Dashboard | https://argocd.chatms.store | ✅ Live |
| Grafana Dashboard | https://grafana.chatms.store | ✅ Live |

---

## 🏗️ Architecture Overview

```
                         INTERNET
                             │
                    GoDaddy Nameservers
                             │
                   Google Cloud DNS
                    chatms.store
               argocd.chatms.store
              grafana.chatms.store
                             │
                    35.225.189.52
                             │
            ┌────────────────────────────────┐
            │   PUBLIC SUBNET 10.0.1.0/24    │
            │   GCP Regional Load Balancer   │
            │   Cloud Router + NAT Gateway   │
            └────────────────┬───────────────┘
                             │
            ┌────────────────────────────────┐
            │  PRIVATE SUBNET 10.0.2.0/24    │
            │                                │
            │   NGINX Ingress Controller     │
            │   (ingress-nginx namespace)    │
            │         │         │        │   │
            │    chat-app   argocd  monitoring│
            │    namespace namespace namespace│
            │                                │
            │   Cloud SQL PostgreSQL 15      │
            │   Private IP: 10.95.0.2        │
            └────────────────────────────────┘
```

### Traffic Flow
1. User visits `chatms.store`
2. GoDaddy → Google Cloud DNS resolves to `35.225.189.52`
3. GCP Regional Load Balancer receives traffic
4. NGINX Ingress Controller routes by hostname:
   - `chatms.store` → `chat-front` service (chat-app namespace)
   - `argocd.chatms.store` → `argocd-server` service (argocd namespace)
   - `grafana.chatms.store` → `grafana` service (monitoring namespace)
5. Application pods handle requests
6. `chat-db` pods connect to Cloud SQL via private IP

### Key Architecture Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Ingress Controller | NGINX (not GCE) | Cross-namespace routing needed |
| Load Balancer | Regional (not Global) | NGINX requires regional LB |
| SSL | cert-manager + Let's Encrypt | Free, auto-renewal |
| Auth | Workload Identity Federation | No JSON keys needed |
| CD | ArgoCD GitOps | Git = single source of truth |
| Nodes | Private GKE nodes | No public IPs on nodes |
| Database | Private Cloud SQL | No public IP on database |

---

## 🛠️ Tech Stack

| Category | Technology | Version |
|----------|-----------|---------|
| Cloud Provider | Google Cloud Platform | - |
| Container Orchestration | Google Kubernetes Engine | v1.35.3 |
| Infrastructure as Code | Terraform | >= 1.3 |
| Containerization | Docker | - |
| CI Pipeline | GitHub Actions | - |
| CD / GitOps | ArgoCD | Latest |
| Ingress | NGINX Ingress Controller | Latest |
| SSL | cert-manager + Let's Encrypt | Latest |
| Metrics | Prometheus | v3.11.3 |
| Logging | Loki + Promtail | Latest |
| Dashboards | Grafana | 12.3.1 |
| DNS | Google Cloud DNS | - |
| Image Registry | Google Artifact Registry | - |
| Database | Cloud SQL PostgreSQL | 15 |
| Application Language | Python Flask | 3.11 |
| Web Server | Gunicorn | Latest |
| Real-time | Flask-SocketIO | 5.3.6 |
| ORM | SQLAlchemy | 2.0.23 |

---

## 📁 Project Structure

```
microservices-chat/
│
├── .github/
│   └── workflows/
│       ├── ci-app.yaml          # App CI/CD pipeline (8 security tools)
│       ├── ci-infra.yaml        # Terraform automation pipeline
│       └── ci-security.yaml     # Nightly security scan (2AM daily)
│
├── terraform/
│   ├── main.tf                  # Provider + GCS remote backend
│   ├── variables.tf             # All input variables
│   ├── outputs.tf               # Important values output
│   ├── networking.tf            # VPC, subnets, firewall rules
│   ├── routing.tf               # Cloud Router + NAT Gateway
│   ├── gke.tf                   # GKE cluster + node pool
│   ├── database.tf              # Cloud SQL PostgreSQL 15
│   ├── dns.tf                   # Cloud DNS + A records
│   ├── registry.tf              # Artifact Registry + IAM
│   └── iam.tf                   # Service account + WIF
│
├── chat_front/                  # Frontend Flask application
│   ├── Dockerfile
│   ├── requirements.txt
│   └── project/
│       └── main.py              # Flask app with Prometheus metrics
│
├── chat_svc/                    # Chat service (Socket.IO)
│   ├── Dockerfile
│   ├── requirements.txt
│   └── project/
│       └── main.py              # Flask + SocketIO with Prometheus metrics
│
├── chat_db/                     # Database service
│   ├── Dockerfile
│   ├── requirements.txt
│   └── project/
│       └── __init__.py          # Flask app factory with Prometheus metrics
│
├── k8s/
│   ├── namespace.yaml           # chat-app namespace
│   ├── ingress.yaml             # chatms.store routing
│   ├── argocd-ingress.yaml      # argocd.chatms.store routing
│   ├── grafana-ingress.yaml     # grafana.chatms.store routing
│   ├── argocd-app.yaml          # ArgoCD Application (GitOps config)
│   ├── chat-front/
│   │   ├── deployment.yaml      # 2 replicas, rolling update
│   │   ├── service.yaml         # ClusterIP service
│   │   └── hpa.yaml             # CPU-based autoscaling 2-6 pods
│   ├── chat-svc/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── hpa.yaml
│   └── chat-db/
│       ├── deployment.yaml
│       └── service.yaml
│
└── monitoring/
    ├── prometheus/
    │   └── values.yaml          # Prometheus Helm configuration
    ├── grafana/
    │   └── values.yaml          # Grafana Helm + datasources + dashboards
    └── loki/
        └── values.yaml          # Loki Helm configuration
```

---

## 🔄 CI/CD Pipeline

### Application Pipeline (`ci-app.yaml`)

Triggered on every push to `master` when changes detected in `chat_front/`, `chat_svc/`, or `chat_db/`:

```
git push → GitHub Actions
        │
        ├── Stage 1: scan-code (15 min timeout)
        │   ├── flake8         (Python style checker)
        │   ├── bandit         (Python security scanner)
        │   ├── pip-audit      (Dependency CVE scanner)
        │   └── trufflehog     (Secret detection in git history)
        │
        ├── Stage 2: scan-terraform (15 min timeout)
        │   ├── tfsec          (Terraform security scanner)
        │   ├── tflint         (Terraform code quality)
        │   └── checkov        (Infrastructure compliance - 100 passed ✅)
        │
        ├── Stage 3: build-push (45 min timeout)
        │   ├── Authenticate to GCP (Workload Identity Federation)
        │   ├── Docker build (chat-front:SHA, chat-svc:SHA, chat-db:SHA)
        │   ├── Trivy scan (OS + Python vulnerabilities)
        │   └── Push to Artifact Registry
        │
        └── Stage 4: update-manifests
            ├── Update image tags in k8s/ deployment files
            ├── git commit and push
            └── ArgoCD detects change → deploys automatically
```

### Infrastructure Pipeline (`ci-infra.yaml`)

Triggered when `terraform/` files change:

```
terraform init → terraform validate → terraform plan → terraform apply
```

### Security Pipeline (`ci-security.yaml`)

Runs nightly at 2:00 AM automatically:
- Dependency vulnerability scanning (all 3 `requirements.txt` files)
- Secret detection in entire git history
- Docker image CVE scanning (all 3 images)
- Python code security analysis

---

## 🚢 GitOps with ArgoCD

ArgoCD watches the `k8s/` folder in the GitHub repository and automatically deploys any changes.

```yaml
# k8s/argocd-app.yaml
spec:
  source:
    repoURL: https://github.com/glare247/microservices-chat
    targetRevision: master
    path: k8s
    directory:
      recurse: true        # reads all subdirectories
  syncPolicy:
    automated:
      prune: true          # deletes removed resources
      selfHeal: true       # reverts manual changes
```

**Access**: https://argocd.chatms.store

### ArgoCD Components

| Pod | Purpose |
|-----|---------|
| argocd-server | Web UI and API |
| argocd-application-controller | Watches cluster state |
| argocd-repo-server | Clones and reads GitHub |
| argocd-dex-server | Authentication |
| argocd-redis | Cache |
| argocd-applicationset-controller | Template management |
| argocd-notifications-controller | Alerts |

---

## 🌐 NGINX Ingress + SSL

### Why NGINX over GCE Ingress

GCE Ingress cannot route across Kubernetes namespaces. ArgoCD lives in the `argocd` namespace and Grafana lives in the `monitoring` namespace — impossible to reach with GCE Ingress.

NGINX Ingress Controller reads ingress rules from ALL namespaces simultaneously.

### SSL Certificates

All SSL certificates are managed automatically by cert-manager + Let's Encrypt:

| Certificate | Domain | Namespace | Status |
|-------------|--------|-----------|--------|
| chat-tls | chatms.store, www.chatms.store | chat-app | ✅ Ready |
| argocd-tls | argocd.chatms.store | argocd | ✅ Ready |
| grafana-tls | grafana.chatms.store | monitoring | ✅ Ready |

### DNS Records

All subdomains point to NGINX Regional Load Balancer:

| Record | IP | TTL |
|--------|-----|-----|
| chatms.store | 35.225.189.52 | 300s |
| www.chatms.store | 35.225.189.52 | 300s |
| argocd.chatms.store | 35.225.189.52 | 300s |
| grafana.chatms.store | 35.225.189.52 | 300s |

---

## ☸️ Kubernetes Configuration

### Application Pods

| Deployment | Replicas | HPA Min | HPA Max | CPU Threshold | Namespace |
|------------|----------|---------|---------|---------------|-----------|
| chat-front | 2 | 2 | 6 | 70% | chat-app |
| chat-svc | 2 | 2 | 6 | 70% | chat-app |
| chat-db | 2 | N/A | N/A | N/A | chat-app |

### Zero-Downtime Deployment Strategy

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # Start 1 new pod before killing old
    maxUnavailable: 0  # Never kill old pod until new passes health check
```

### Health Probes

Every pod has both liveness and readiness probes:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
```

### PersistentVolumeClaims

| PVC | Size | Namespace | Used By |
|-----|------|-----------|---------|
| prometheus-server | 10Gi | monitoring | Prometheus metrics storage |
| grafana | 5Gi | monitoring | Grafana dashboard storage |
| storage-loki-0 | 10Gi | monitoring | Loki log storage |

---

## 📊 Observability Stack

### Architecture

```
All Pods → Promtail (DaemonSet on every node)
                  → Loki (log storage)
                         → Grafana (visualization)

All Pods → Prometheus (scrapes /metrics every 30s)
                  → Grafana (visualization)
```

### Prometheus Metrics

All Flask applications expose `/metrics` endpoint using `prometheus-flask-exporter`:

```python
# Added to chat_front/project/main.py
# Added to chat_svc/project/main.py
# Added to chat_db/project/__init__.py

from prometheus_flask_exporter import PrometheusMetrics
metrics = PrometheusMetrics(app)
```

All 6 chat-app pods confirmed scraped (`up=1`):
```
job=kubernetes-pods | namespace=chat-app | up=1 ✅ (×6)
```

### Grafana Dashboards

| Dashboard | gnetId | Status | Shows |
|-----------|--------|--------|-------|
| Node Exporter Full | 11074 | ✅ Working | CPU 15.9%, RAM 49.6%, Disk 73.7% |
| Kubernetes Cluster Monitoring | 3119 | ✅ Working | Cluster CPU, Memory, Network |
| NGINX Ingress Controller | 9614 | ✅ Working | Request volume, connections |

**Access**: https://grafana.chatms.store

---

## 🔒 Security Features

### Infrastructure Security

| Feature | Implementation | Benefit |
|---------|---------------|---------|
| Workload Identity Federation | `terraform/iam.tf` | No JSON keys ever stored |
| Private GKE nodes | `terraform/gke.tf` | Nodes have no public IPs |
| Private Cloud SQL | `terraform/database.tf` | Database unreachable from internet |
| Least privilege IAM | `terraform/iam.tf` | 7 specific roles only |
| DNSSEC | `terraform/dns.tf` | Prevents DNS hijacking |
| SSL everywhere | cert-manager | All endpoints HTTPS |
| VPC firewall | `terraform/networking.tf` | Only ports 80/443 open |

### CI Security Scanning

| Tool | What It Scans | Stage |
|------|--------------|-------|
| flake8 | Python code style | scan-code |
| bandit | Python security vulnerabilities | scan-code |
| pip-audit | Python dependency CVEs | scan-code |
| trufflehog | Secrets in git history | scan-code |
| tfsec | Terraform security | scan-terraform |
| tflint | Terraform code quality | scan-terraform |
| checkov | Infrastructure compliance (100 passed ✅) | scan-terraform |
| trivy | Docker image CVEs | build-push |

---

## 🏗️ Terraform Infrastructure

### Remote State

```hcl
# terraform/main.tf
backend "gcs" {
  bucket = "kabiru-devops-tfstate-001"
  prefix = "terraform/state"
}
```

State stored in GCS bucket — shared across CI pipeline and team members, never lost.

### Resources Created

| File | Resources Created |
|------|------------------|
| `networking.tf` | VPC, public subnet, private subnet, firewall rules |
| `routing.tf` | Cloud Router, NAT Gateway |
| `gke.tf` | GKE cluster (regional), node pool (e2-medium, autoscaling 1-3) |
| `database.tf` | Cloud SQL PostgreSQL 15, database, user, backups |
| `dns.tf` | DNS managed zone, 4 A records (data source for nginx-lb-ip) |
| `registry.tf` | Artifact Registry, IAM for GKE pull, IAM for CI push |
| `iam.tf` | Service account, 7 IAM roles, WIF pool, WIF provider |

### Checkov Results

```
Passed checks: 100
Failed checks: 0
Skipped checks: 11 (all documented with reasons)
```

---

## 🚀 Deployment Guide

### Prerequisites

```bash
# Required tools
terraform >= 1.3
kubectl
helm >= 3.0
gcloud CLI
docker
```

### Step 1 — Infrastructure

```bash
# Clone repository
git clone https://github.com/glare247/microservices-chat
cd microservices-chat/terraform

# Initialize and apply
terraform init
terraform plan
terraform apply

# Connect to GKE cluster
gcloud container clusters get-credentials \
  chat-platform-cluster \
  --region us-central1 \
  --project microservices-chat-496017
```

### Step 2 — Add Helm Repositories

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### Step 3 — Install Core Components

```bash
# NGINX Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.metrics.enabled=true

# cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true

# ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd --create-namespace
```

### Step 4 — Apply Kubernetes Manifests

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/argocd-app.yaml
# ArgoCD will automatically apply all other manifests
```

### Step 5 — Install Monitoring Stack

```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Prometheus
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --values monitoring/prometheus/values.yaml

# Loki
helm install loki grafana/loki \
  --namespace monitoring \
  --values monitoring/loki/values.yaml

# Promtail
helm install promtail grafana/promtail \
  --namespace monitoring \
  --set config.clients[0].url=http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push

# Grafana
helm install grafana grafana/grafana \
  --namespace monitoring \
  --values monitoring/grafana/values.yaml
```

### Step 6 — Verify Deployment

```bash
# Check all pods running
kubectl get pods --namespace chat-app
kubectl get pods --namespace argocd
kubectl get pods --namespace monitoring

# Check SSL certificates
kubectl get certificate --namespace chat-app
kubectl get certificate --namespace argocd
kubectl get certificate --namespace monitoring

# Check ingress
kubectl get ingress --all-namespaces
```

---

## 🔧 Operations Guide

### Get ArgoCD Admin Password

```bash
kubectl get secret \
  argocd-initial-admin-secret \
  --namespace argocd \
  -o jsonpath='{.data.password}' \
  | base64 -d && echo
```

### Get Grafana Admin Password

```bash
kubectl get secret grafana \
  --namespace monitoring \
  -o jsonpath='{.data.admin-password}' \
  | base64 -d && echo
```

### Scale Application

```bash
kubectl scale deployment chat-front \
  --namespace chat-app \
  --replicas=3
```

### View Application Logs

```bash
kubectl logs \
  -l app=chat-front \
  --namespace chat-app \
  --follow
```

### Check Prometheus Targets

```bash
kubectl port-forward \
  service/prometheus-server \
  --namespace monitoring \
  9090:80

# Open http://localhost:9090/targets
```

### Connect to Database

```bash
# Cloud SQL private IP: 10.95.0.2
# Connection via chat-db service only
# Never exposed publicly
```

---

## 📈 GCP Resources

| Resource | Name | Details |
|----------|------|---------|
| GKE Cluster | chat-platform-cluster | Regional, us-central1, 4 nodes |
| Node Type | e2-medium | 2 vCPU, 4GB RAM per node |
| Node Autoscaling | 1-3 per zone | Scales automatically |
| Cloud SQL | chat-postgres-db | PostgreSQL 15, Regional HA |
| SQL Private IP | 10.95.0.2 | No public IP |
| Load Balancer | nginx-lb-ip | Regional, 35.225.189.52 |
| Artifact Registry | chat-platform-cluster-registry | us-central1 |
| DNS Zone | chatms.store | Google Cloud DNS |
| State Bucket | kabiru-devops-tfstate-001 | Terraform remote state |
| GCP Region | us-central1 | Iowa, USA |
| GCP Project | microservices-chat-496017 | - |

---

## 🐛 Troubleshooting

### Pod CrashLoopBackOff

```bash
# Check pod logs
kubectl logs POD_NAME --namespace NAMESPACE --previous

# Check pod events
kubectl describe pod POD_NAME --namespace NAMESPACE | grep -A 20 "Events:"
```

### Certificate Not Ready

```bash
# Check certificate status
kubectl describe certificate CERT_NAME --namespace NAMESPACE

# Check cert-manager logs
kubectl logs -l app=cert-manager --namespace cert-manager
```

### Prometheus Not Scraping

```bash
# Check targets
kubectl exec -it PROMETHEUS_POD --namespace monitoring \
  -c prometheus-server \
  -- wget -qO- http://localhost:9090/api/v1/targets
```

### DNS Not Resolving

```bash
# Check DNS records
gcloud dns record-sets list \
  --zone=chat-platform-cluster-dns-zone \
  --project=microservices-chat-496017

# Verify nslookup
nslookup chatms.store
```

### ArgoCD Out of Sync

```bash
# Force sync
argocd app sync chat-platform

# Or via UI at https://argocd.chatms.store
```

---

## 📝 Environment Variables

All sensitive values stored in Kubernetes Secrets and GitHub Secrets:

| Secret | Used By | Contains |
|--------|---------|----------|
| `chat-db-secret` | All pods | DB URI, SECRET_KEY, service hosts |
| `WIF_PROVIDER` | GitHub Actions | Workload Identity provider URL |
| `WIF_SERVICE_ACCOUNT` | GitHub Actions | Service account email |
| `TF_VAR_DB_PASSWORD` | GitHub Actions | Database password |

---

## 🏆 Skills Demonstrated

| Skill Area | Technologies |
|-----------|-------------|
| Cloud Engineering | GCP, VPC, GKE, Cloud SQL, Artifact Registry |
| Infrastructure as Code | Terraform, remote state, checkov, tfsec |
| Containerization | Docker, multi-layer caching, Trivy scanning |
| Kubernetes | Deployments, Services, Ingress, HPA, Secrets |
| CI/CD | GitHub Actions, 8 security tools, WIF auth |
| GitOps | ArgoCD, declarative deployments, self-healing |
| Networking | NGINX Ingress, SSL/TLS, DNS, Load Balancing |
| Observability | Prometheus, Grafana, Loki, Promtail |
| Security | WIF, private clusters, least privilege IAM |
| Python | Flask, SQLAlchemy, Socket.IO, Gunicorn |

---

## 👨‍💻 Developer

**Kabiru** — Aspiring DevOps Engineer

- **GitHub**: [@glare247](https://github.com/glare247)
- **Repository**: [microservices-chat](https://github.com/glare247/microservices-chat)
- **Stack**: GCP · Kubernetes · Terraform · GitHub Actions · ArgoCD · Prometheus · Grafana

---

## 📄 License

This project is for portfolio and educational purposes.

---

*Built with ❤️ as a production-grade DevOps portfolio project*