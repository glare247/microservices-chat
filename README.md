# 🚀 Production Grade Microservices Chat Platform on GCP/GKE

A fully production-grade cloud-native chat application deployed on Google Kubernetes Engine (GKE) with complete CI/CD, GitOps, SSL, monitoring and observability. Built as a DevOps portfolio project demonstrating real-world enterprise skills.

---

## 🌐 Live URLs

| Service | URL | Status |
|---------|-----|--------|
| Chat App | https://chatms.store | ✅ Live |
| ArgoCD | https://argocd.chatms.store | ✅ Live |
| Grafana | https://grafana.chatms.store | ✅ Live |

---

## 🏗️ Architecture Overview

```
INTERNET
    │
    ▼
GoDaddy DNS → Google Cloud DNS
chatms.store → 35.225.189.52
    │
    ▼
GCP Regional Load Balancer (35.225.189.52)
    │
    ▼
NGINX Ingress Controller (ingress-nginx namespace)
    │
    ├─── PATH: /            ──→ chat-front  (serves HTML, CSS, JS)
    │
    └─── PATH: /socket.io   ──→ chat-svc   (real-time messaging)
                                    │
                                    │ HTTP REST
                                    ▼
                                chat-db
                                    │
                                    │ SQL queries
                                    ▼
                              Cloud SQL PostgreSQL 15
                              Private IP: 10.95.0.2
```

### Browser Flow

```
Step 1 — Load Page:
  Browser → NGINX → chat-front
  Returns: HTML + socket.io.min.js v4

Step 2 — Socket.IO Connect:
  Browser → NGINX → chat-svc (directly via /socket.io)
  Result: WebSocket connection established

Step 3 — Send Message:
  Browser → NGINX → chat-svc → chat-db → PostgreSQL
  Result: Message stored and broadcast to all users
```

### Network Design

```
PUBLIC SUBNET  10.0.1.0/24 → GCP Load Balancer, Cloud Router, NAT
PRIVATE SUBNET 10.0.2.0/24 → GKE nodes, Cloud SQL (no public IPs)
```

---

## 🛠️ Tech Stack

| Category | Technology | Version |
|----------|-----------|---------|
| Cloud Provider | Google Cloud Platform | - |
| Container Orchestration | GKE | v1.35.3 |
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
| Language | Python Flask | 3.11 |
| Web Server | Gunicorn + Eventlet | Latest |
| Real-time | Flask-SocketIO + Socket.IO | 5.3.6 / v4.7.5 |

---

## 📁 Project Structure

```
microservices-chat/
├── .github/
│   └── workflows/
│       ├── ci-app.yaml           # App CI/CD pipeline (8 security tools)
│       ├── ci-infra.yaml         # Terraform automation pipeline
│       └── ci-security.yaml      # Nightly security scan
├── terraform/
│   ├── main.tf                   # Provider + GCS remote backend
│   ├── networking.tf             # VPC, subnets, firewall rules
│   ├── routing.tf                # Cloud Router + NAT Gateway
│   ├── gke.tf                    # GKE cluster + node pool
│   ├── database.tf               # Cloud SQL PostgreSQL 15
│   ├── dns.tf                    # Cloud DNS + A records
│   ├── registry.tf               # Artifact Registry + IAM
│   └── iam.tf                    # Service account + WIF
├── chat_front/                   # Frontend Flask app (serves HTML/JS)
├── chat_svc/                     # Chat service (Socket.IO server)
├── chat_db/                      # Database service (REST API)
├── k8s/
│   ├── namespace.yaml            # chat-app namespace
│   ├── ingress.yaml              # NGINX routing + sticky sessions
│   ├── argocd-ingress.yaml       # ArgoCD subdomain routing
│   ├── grafana-ingress.yaml      # Grafana subdomain routing
│   ├── argocd-app.yaml           # ArgoCD Application (GitOps config)
│   ├── chat-front/               # Deployment, Service, HPA
│   ├── chat-svc/                 # Deployment, Service, HPA
│   └── chat-db/                  # Deployment, Service
└── monitoring/
    ├── prometheus/values.yaml    # Prometheus Helm config
    ├── grafana/values.yaml       # Grafana Helm + dashboards
    └── loki/values.yaml          # Loki Helm config
```

---

## 🔄 CI/CD Pipeline

### Application Pipeline (ci-app.yaml)

Triggered on every push to `master` when app code changes:

```
git push → GitHub Actions
    │
    ├── Stage 1: scan-code
    │   ├── flake8         Python style checker
    │   ├── bandit         Python security scanner
    │   ├── pip-audit      Dependency CVE scanner
    │   └── trufflehog     Secret detection in git history
    │
    ├── Stage 2: scan-terraform
    │   ├── tfsec          Terraform security scanner
    │   ├── tflint         Terraform code quality
    │   └── checkov        Infrastructure compliance (100 passed ✅)
    │
    ├── Stage 3: build-push
    │   ├── Authenticate via Workload Identity Federation
    │   ├── Docker build (chat-front, chat-svc, chat-db)
    │   ├── Trivy image scan (OS + Python CVEs)
    │   └── Push to Artifact Registry
    │
    └── Stage 4: update-manifests
        ├── Update image tags in k8s/ deployment files
        ├── git commit and push
        └── ArgoCD detects change → deploys automatically
```

### Infrastructure Pipeline (ci-infra.yaml)

Triggered when `terraform/` files change:

```
terraform init → terraform validate → terraform plan → terraform apply
```

### Security Pipeline (ci-security.yaml)

Runs nightly at 2:00 AM:
- Dependency vulnerability scanning
- Secret detection in git history
- Docker image CVE scanning
- Python code security analysis

---

## 🚢 GitOps with ArgoCD

ArgoCD watches the `k8s/` folder on GitHub and automatically deploys any changes.

```yaml
spec:
  source:
    repoURL: https://github.com/glare247/microservices-chat
    targetRevision: master
    path: k8s
    directory:
      recurse: true
  syncPolicy:
    automated:
      prune: true        # deletes removed resources
      selfHeal: true     # reverts manual changes
```

**Access**: https://argocd.chatms.store

---

## 🌐 NGINX Ingress + SSL

### Routing Rules

| Path | Service | Namespace |
|------|---------|-----------|
| chatms.store/ | chat-front | chat-app |
| chatms.store/socket.io | chat-svc | chat-app |
| argocd.chatms.store | argocd-server | argocd |
| grafana.chatms.store | grafana | monitoring |

### SSL Certificates

| Domain | Certificate | Status |
|--------|-------------|--------|
| chatms.store | Let's Encrypt | ✅ Ready |
| argocd.chatms.store | Let's Encrypt | ✅ Ready |
| grafana.chatms.store | Let's Encrypt | ✅ Ready |

### Sticky Sessions for Socket.IO

Socket.IO requires all requests from the same browser to reach the same pod:

```yaml
nginx.ingress.kubernetes.io/affinity: "cookie"
nginx.ingress.kubernetes.io/session-cookie-name: "chat-svc-affinity"
nginx.ingress.kubernetes.io/session-cookie-expires: "172800"
```

### DNS Records

All subdomains point to NGINX Regional Load Balancer IP:

| Record | IP |
|--------|-----|
| chatms.store | 35.225.189.52 |
| www.chatms.store | 35.225.189.52 |
| argocd.chatms.store | 35.225.189.52 |
| grafana.chatms.store | 35.225.189.52 |

---

## ☸️ Kubernetes Configuration

### Application Pods

| Deployment | Replicas | HPA Min | HPA Max | CPU Threshold | Namespace |
|------------|----------|---------|---------|---------------|-----------|
| chat-front | 2 | 2 | 6 | 70% | chat-app |
| chat-svc | 2 | 2 | 6 | 70% | chat-app |
| chat-db | 2 | - | - | - | chat-app |

### Deployment Strategy

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

### PersistentVolumeClaims

| PVC | Size | Used By |
|-----|------|---------|
| prometheus-server | 10Gi | Prometheus metrics storage |
| grafana | 5Gi | Grafana dashboard storage |
| storage-loki-0 | 10Gi | Loki log storage |

---

## 📊 Observability Stack

### Architecture

```
All Pods → Promtail (DaemonSet) → Loki → Grafana
All Pods → Prometheus (scrapes /metrics) → Grafana
```

### Grafana Dashboards

| Dashboard | gnetId | Shows |
|-----------|--------|-------|
| Node Exporter Full | 11074 | CPU 15.9%, RAM 49.6%, Disk 73.7% |
| Kubernetes Cluster Monitoring | 3119 | Cluster CPU, Memory, Network |
| NGINX Ingress Controller | 9614 | Request volume, connections |

All 6 chat-app pods confirmed scraped by Prometheus (up=1 ✅)

**Grafana**: https://grafana.chatms.store

---

## 🔒 Security Features

| Feature | Implementation | Benefit |
|---------|---------------|---------|
| Workload Identity Federation | terraform/iam.tf | No JSON keys stored anywhere |
| Private GKE nodes | terraform/gke.tf | Nodes have no public IPs |
| Private Cloud SQL | terraform/database.tf | Database unreachable from internet |
| Least privilege IAM | terraform/iam.tf | 7 specific roles only |
| DNSSEC | terraform/dns.tf | Prevents DNS hijacking |
| SSL everywhere | cert-manager | All endpoints HTTPS only |
| VPC firewall | terraform/networking.tf | Only ports 80/443 open |

### CI Security Tools

| Tool | Scans |
|------|-------|
| flake8 | Python code style |
| bandit | Python security vulnerabilities |
| pip-audit | Python dependency CVEs |
| trufflehog | Secrets in git history |
| tfsec | Terraform security |
| tflint | Terraform code quality |
| checkov | Infrastructure compliance (100 passed ✅) |
| trivy | Docker image CVEs |

---

## ⚠️ Important Implementation Notes

### Socket.IO Architecture Change

The original framework design had the browser connecting to `chat-front` which then proxied to `chat-svc`. In our Kubernetes deployment this was changed:

**Original design (single server):**
```
Browser → chat-front → chat-svc (internal proxy)
```

**Production Kubernetes design:**
```
Browser → NGINX → chat-front    (page load only)
Browser → NGINX → chat-svc      (all Socket.IO traffic)
```

**Why changed:** In Kubernetes each service has its own internal DNS name (e.g. `chat-svc`). Browsers cannot resolve internal Kubernetes DNS from outside the cluster. NGINX Ingress routes `/socket.io` directly to `chat-svc` using the public domain name.

### Socket.IO Version Compatibility

| Component | Version | Protocol |
|-----------|---------|---------|
| socket.io.min.js (browser client) | v4.7.5 | EIO=4 |
| Flask-SocketIO (server) | 5.3.6 | EIO=4 |

Both client and server must use EIO=4. Using mismatched versions causes 400 Bad Request errors on all Socket.IO connections.

### Eventlet Monkey Patching

```python
# chat_svc/manage.py
# MUST be first before any other imports
import eventlet
eventlet.monkey_patch()

from project.main import create_app, socketio
app = create_app()
```

Required for correct async DNS resolution when using Gunicorn with eventlet worker class in GKE.

### on_connect Handler Signature

Flask-SocketIO v5.x passes an `auth` parameter to the connect handler:

```python
# Correct for Flask-SocketIO 5.x
@socketio.on('connect', namespace='/chat')
def on_connect(auth):
    pass
```

---

## 🚀 Deployment Guide

### Prerequisites

```bash
terraform >= 1.3
kubectl
helm >= 3.0
gcloud CLI
docker
```

### Step 1 — Clone and Setup Infrastructure

```bash
git clone https://github.com/glare247/microservices-chat
cd microservices-chat/terraform
terraform init
terraform apply

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
  --namespace ingress-nginx --create-namespace

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
# ArgoCD will automatically apply all remaining manifests
```

### Step 5 — Install Monitoring Stack

```bash
kubectl create namespace monitoring

helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --values monitoring/prometheus/values.yaml

helm install loki grafana/loki \
  --namespace monitoring \
  --values monitoring/loki/values.yaml

helm install promtail grafana/promtail \
  --namespace monitoring \
  --set config.clients[0].url=http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push

helm install grafana grafana/grafana \
  --namespace monitoring \
  --values monitoring/grafana/values.yaml
```

### Step 6 — Verify Deployment

```bash
kubectl get pods --namespace chat-app
kubectl get pods --namespace argocd
kubectl get pods --namespace monitoring
kubectl get certificate --all-namespaces
kubectl get ingress --all-namespaces
```

---

## 🔧 Operations Guide

### Get ArgoCD Admin Password

```bash
kubectl get secret argocd-initial-admin-secret \
  --namespace argocd \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

### View Application Logs

```bash
kubectl logs -l app=chat-front --namespace chat-app --follow
kubectl logs -l app=chat-svc --namespace chat-app --follow
kubectl logs -l app=chat-db --namespace chat-app --follow
```

### Check Prometheus Targets

```bash
kubectl port-forward service/prometheus-server \
  --namespace monitoring 9090:80
# Open http://localhost:9090/targets
```

### Scale Application

```bash
kubectl scale deployment chat-front \
  --namespace chat-app --replicas=3
```

---

## 📈 GCP Resources

| Resource | Name | Details |
|----------|------|---------|
| GKE Cluster | chat-platform-cluster | Regional, us-central1, 4 nodes |
| Node Type | e2-medium | 2 vCPU, 4GB RAM per node |
| Cloud SQL | chat-postgres-db | PostgreSQL 15, Regional HA |
| SQL Private IP | 10.95.0.2 | No public IP |
| Load Balancer | nginx-lb-ip | Regional, 35.225.189.52 |
| Artifact Registry | chat-platform-cluster-registry | us-central1 |
| DNS Zone | chatms.store | Google Cloud DNS |
| State Bucket | kabiru-devops-tfstate-001 | Terraform remote state |
| GCP Region | us-central1 | Iowa, USA |
| GCP Project | microservices-chat-496017 | - |

---

## 🏆 Skills Demonstrated

| Skill Area | Technologies |
|-----------|-------------|
| Cloud Engineering | GCP, VPC, GKE, Cloud SQL, Artifact Registry, Cloud DNS |
| Infrastructure as Code | Terraform, remote state, modules, checkov, tfsec |
| Containerization | Docker, multi-layer caching, Trivy scanning |
| Kubernetes | Deployments, Services, Ingress, HPA, Secrets, PVCs |
| CI/CD | GitHub Actions, 8 security tools, WIF authentication |
| GitOps | ArgoCD, declarative deployments, self-healing |
| Networking | NGINX Ingress, SSL/TLS, DNS, Load Balancing, WebSockets |
| Observability | Prometheus, Grafana, Loki, Promtail |
| Security | WIF, private clusters, least privilege IAM, DNSSEC |
| Python | Flask, SQLAlchemy, Flask-SocketIO, Gunicorn, Eventlet |

---

## 👨‍💻 Developer

**Kabiru** — Aspiring DevOps Engineer

- **GitHub**: [@glare247](https://github.com/glare247)
- **Repository**: [microservices-chat](https://github.com/glare247/microservices-chat)
- **Stack**: GCP · Kubernetes · Terraform · GitHub Actions · ArgoCD · Prometheus · Grafana

---

*Built as a production-grade DevOps portfolio project* 🚀