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

## 📸 Project Screenshots

### 1. Chat Application — Live at chatms.store

> Username prompt on connect

<img width="1792" height="1120" alt="Screenshot 2026-06-09 at 11 46 29 AM" src="https://github.com/user-attachments/assets/93c5adb5-c61a-4714-8d27-ef7f13133bd6" />


> Real-time messages working

<img width="1792" height="1120" alt="Screenshot 2026-06-09 at 11 47 30 AM" src="https://github.com/user-attachments/assets/29adc38f-6488-49ef-9d2f-b417b57f76f5" />


---

### 2. ArgoCD — GitOps Dashboard

> Application Healthy and Synced to GitHub master branch

<img width="1792" height="1120" alt="Screenshot 2026-06-09 at 11 50 43 AM" src="https://github.com/user-attachments/assets/fea102b6-499b-490d-8eaf-c73cad9f6fc2" />


> Full application resource tree — 48 healthy resources, 13 synced
<img width="1792" height="1120" alt="Screenshot 2026-06-09 at 11 52 07 AM" src="https://github.com/user-attachments/assets/8cfd1433-eb4a-430d-b3a2-40c92a358683" />
<img width="1792" height="1120" alt="Screenshot 2026-06-09 at 11 53 35 AM" src="https://github.com/user-attachments/assets/325abb79-661c-4449-a710-d11f482b47c6" />



---

### 3. Grafana — Observability Dashboards

> Node Exporter Full — CPU 19.4%, RAM 51.7%, Disk 73.8%, Uptime 2.1 days
<img width="1792" height="1120" alt="Screenshot 2026-06-09 at 11 54 35 AM" src="https://github.com/user-attachments/assets/c039fa37-1484-4cc4-86fa-f9cfa927115f" />



> Kubernetes Cluster Monitoring — Memory 43.6%, CPU 3.43%, Network I/O live
<img width="1792" height="1120" alt="Screenshot 2026-06-09 at 11 54 54 AM" src="https://github.com/user-attachments/assets/b6595ac1-98a9-44f9-acb5-b2c92597650b" />



> NGINX Ingress Controller — 0.0717 ops/s, 15.6 connections, 89.8% success rate

<img width="1792" height="1120" alt="Screenshot 2026-06-09 at 11 55 08 AM" src="https://github.com/user-attachments/assets/356115b9-ec34-4cea-ab77-39ab952cabef" />

---

### 4. GitHub Actions — CI/CD Pipeline

> Latest pipeline run — All 3 stages passing in 4m 26s
<img width="1792" height="1120" alt="Screenshot 2026-06-09 at 11 55 44 AM" src="https://github.com/user-attachments/assets/9399e7fd-5056-48df-bf4e-1c959970644c" />



> Full pipeline history — App pipelines green, Security nightly scans visible


<img width="1792" height="1120" alt="Screenshot 2026-06-09 at 11 56 28 AM" src="https://github.com/user-attachments/assets/754c32fe-93f4-497d-9437-08b4d6570b7e" />

---

### 5. Google Cloud Platform

> GKE Cluster — chat-platform-cluster, us-central1, 4 nodes, 8 vCPUs, 16GB RAM, 100% healthy
<img width="1792" height="1120" alt="Screenshot 2026-06-09 at 12 14 49 PM" src="https://github.com/user-attachments/assets/0c499b91-4330-4bd3-b5e5-5f6e8db5378c" />


> VPC Network — chat-platform-cluster-vpc with 3 subnets, 9 firewall rules
> <img width="1792" height="1120" alt="Screenshot 2026-06-09 at 12 12 41 PM" src="https://github.com/user-attachments/assets/c54e5160-02f8-4f49-ab1c-b0a8faf9efe9" />

>
> <img width="1792" height="1120" alt="Screenshot 2026-06-09 at 12 13 26 PM" src="https://github.com/user-attachments/assets/1abd3a5c-9a47-416e-b2d5-12cb09e63a09" />




> GKE Node VMs — 4 private nodes across us-central1-a and us-central1-b (no public IPs)



<img width="1792" height="1120" alt="Screenshot 2026-06-09 at 12 16 11 PM" src="https://github.com/user-attachments/assets/dee17129-4b48-4cfa-8388-3adcbea4b83e" />

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
| CD / GitOps | ArgoCD | v3.4.2 |
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
| Node Exporter Full | 11074 | CPU 19.4%, RAM 51.7%, Disk 73.8% |
| Kubernetes Cluster Monitoring | 3119 | Memory 43.6%, CPU 3.43% |
| NGINX Ingress Controller | 9614 | 0.0717 ops/s, 15.6 connections |

All 6 chat-app pods confirmed scraped by Prometheus (up=1 ✅)

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

**Original design (single server):**
```
Browser → chat-front → chat-svc (internal proxy)
```

**Production Kubernetes design:**
```
Browser → NGINX → chat-front    (page load only)
Browser → NGINX → chat-svc      (all Socket.IO traffic)
```

**Why changed:** In Kubernetes each service has its own internal DNS. Browsers cannot resolve internal Kubernetes DNS from outside the cluster. NGINX routes `/socket.io` directly to `chat-svc` using the public domain name.

### Socket.IO Version Compatibility

| Component | Version | Protocol |
|-----------|---------|---------|
| socket.io.min.js (browser client) | v4.7.5 | EIO=4 |
| Flask-SocketIO (server) | 5.3.6 | EIO=4 |

### Eventlet Monkey Patching

```python
# chat_svc/manage.py — MUST be first before any imports
import eventlet
eventlet.monkey_patch()

from project.main import create_app, socketio
app = create_app()
```

### on_connect Handler Signature

```python
# Flask-SocketIO 5.x requires auth parameter
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
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true

helm install argocd argo/argo-cd \
  --namespace argocd --create-namespace
```

### Step 4 — Apply Kubernetes Manifests

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/argocd-app.yaml
# ArgoCD deploys everything else automatically
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
kubectl logs -l app=chat-svc --namespace chat-app --follow
```

### Check All Pods

```bash
kubectl get pods --all-namespaces
```

---

## 📈 GCP Resources

| Resource | Name | Details |
|----------|------|---------|
| GKE Cluster | chat-platform-cluster | Regional, us-central1, 4 nodes |
| Node Type | e2-medium | 2 vCPU, 4GB RAM per node |
| Total Compute | - | 8 vCPUs, 16 GB RAM |
| Cloud SQL | chat-postgres-db | PostgreSQL 15, Regional HA |
| SQL Private IP | 10.95.0.2 | No public IP |
| Load Balancer | nginx-lb-ip | Regional, 35.225.189.52 |
| Artifact Registry | chat-platform-cluster-registry | us-central1 |
| DNS Zone | chatms.store | Google Cloud DNS |
| State Bucket | kabiru-devops-tfstate-001 | Terraform remote state |
| VPC Network | chat-platform-cluster-vpc | 3 subnets, 9 firewall rules |
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
