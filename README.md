# AWS Kubernetes Migration - Student CRUD Application

Migrating a Java Spring Boot CRUD application from EC2 to Kubernetes with improved scalability, observability, and maintainability.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [API Endpoints](#api-endpoints)
- [Configuration Reference](#configuration-reference)
- [Scaling Configuration](#scaling-configuration)
- [Observability](#observability)
- [Security](#security)
- [AWS Deployment](#aws-deployment)
- [Troubleshooting](#troubleshooting)
- [Known Limitations & Future Improvements](#known-limitations--future-improvements)

## Overview

| Feature | Implementation |
|---------|---------------|
| **Containerization** | Multi-stage Docker build (JDK build → JRE runtime) |
| **Kubernetes** | Deployments, Services, Secrets, Health Probes |
| **Database** | PostgreSQL (local) / Aurora PostgreSQL (AWS) |
| **Observability** | Grafana + Loki + Prometheus + Promtail |
| **Scalability** | HPA with CPU/Memory metrics (2-10 replicas) |

## Architecture

```text
┌───────────────────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster (Kind / EKS)                   │
│                                                                           │
│  ┌─────────────────────────────┐     ┌────────────────────────────────┐   │
│  │    Namespace: student-app   │     │     Namespace: monitoring      │   │
│  │                             │     │                                │   │
│  │  ┌───────────────────────┐  │     │  ┌───────────┐  ┌───────────┐  │   │
│  │  │      Deployment       │  │     │  │  Grafana  │  │   Loki    │  │   │
│  │  │  ┌─────┐    ┌─────┐   │  │     │  │  :30300   │  │  :3100    │  │   │
│  │  │  │ Pod │◄──►│ Pod │   │  │     │  └─────┬─────┘  └─────▲─────┘  │   │
│  │  │  │ 1-10│    │ ... │   │  │     │        │              │        │   │
│  │  │  └─────┘    └─────┘   │  │     │        │         ┌────┴──────┐ │   │
│  │  └───────────────────────┘  │     │        │         │ Promtail  │ │   │
│  │            ▲                │     │        │         │(DaemonSet)│ │   │
│  │            │                │     │        │         └───────────┘ │   │
│  │  ┌─────────┴─────────┐      │     │        │                       │   │
│  │  │   Service :30080  │      │     │  ┌─────┴─────┐                 │   │
│  │  └───────────────────┘      │     │  │Prometheus │                 │   │
│  │            ▲                │     │  │  :9090    │                 │   │
│  │  ┌─────────┴─────────┐      │     │  └───────────┘                 │   │
│  │  │        HPA        │      │     │                                │   │
│  │  │   (2-10 replicas) │      │     │                                │   │
│  │  │  CPU>70% MEM>80%  │      │     │                                │   │
│  │  └───────────────────┘      │     │                                │   │
│  └─────────────────────────────┘     └────────────────────────────────┘   │
│                │                                                          │
└────────────────┼──────────────────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────┐
│     PostgreSQL / Aurora RDS    │
│         (Database)             │
└────────────────────────────────┘
```

## Project Structure

```text
├── app/                      # Spring Boot application source
├── Dockerfile                # Multi-stage build
├── docker-compose.yml        # Local development
├── k8s/
│   ├── application/          # App manifests (deployment, service, hpa, secrets)
│   └── monitoring/           # Observability stack (grafana, loki, prometheus, promtail)
├── kind/                     # Kind cluster config + metrics-server
├── dashboard/                # Grafana dashboard JSON
└── aws/                      # AWS infrastructure (Terraform based)
```

## Prerequisites

### Local Development

- Docker
- kubectl
- Kind (for local Kubernetes)
- Helm (for kube-state-metrics)

### AWS Deployment

- AWS CLI (configured with credentials)
- Terraform >= 1.0
- AWS IAM permissions for: VPC, EKS, RDS, EC2, IAM

```bash
# Verify AWS CLI
aws --version
aws sts get-caller-identity

# Verify Terraform
terraform version
```

## Quick Start

### 1. Build and push Docker Image

```bash
# Build
docker build -t student-java-crud-app:latest .

# Retag
docker tag student-java-crud-app:latest <registry>/<repo>:<version>

# Push
docker push <registry>/<repo>:<version>
```

### 2. Local Testing with Docker Compose

```bash
docker-compose up --build

# Test API
curl http://localhost:8080/api/v1/student


docker-compose down
```

### 3. Deploy to Kind Cluster

```bash
# Create cluster
kind create cluster --config kind/kind-cluster.yaml

# Install metrics-server (required for HPA)
kubectl apply -f kind/metrics_server_components.yaml

# Install kube-state-metrics
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-state-metrics prometheus-community/kube-state-metrics
```

#### Configure Database Secret

Create base namespace for application:

```bash
kubectl create namespace student-app
```

**Option A: Use existing YAML file**:

```bash
kubectl apply -f k8s/application/student_app_secret_kind.yaml
```

**Option B: Create manually via CLI**:

```bash
kubectl create secret generic app-secret \
  --namespace student-app \
  --from-literal=SPRING_DATASOURCE_URL="jdbc:postgresql://postgres:5432/student" \
  --from-literal=SPRING_DATASOURCE_USERNAME="postgres" \
  --from-literal=SPRING_DATASOURCE_PASSWORD="postgres"
```

#### Deploy Application & Monitoring

```bash
# Deploy application
kubectl apply -f k8s/application/

# Wait until all application pods are running
kubectl -n student-app get pods

# Deploy monitoring stack
kubectl apply -f k8s/monitoring/namespace.yaml
kubectl apply -f k8s/monitoring/

# Wait until all pods run
kubectl -n monitoring get pods
```

### 4. Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Application | [http://<NODE_IP>:30080/api/v1/student](http://<NODE_IP>:30080/api/v1/student) | - |
| Grafana | [http://<NODE_IP>:30300](http://<NODE_IP>:30300) | admin / admin123 |

#### Get Cluster Node IP Address

```bash
# Get node IP (for Kind or any K8s cluster)
kubectl get nodes -o wide

# Example output:
# NAME                 STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP
# kind-control-plane   Ready    control-plane   1d    v1.27.3   172.18.0.2     <none>
```

#### Access Services via NodePort

```bash
# Get NodePort for each service
kubectl get svc -n student-app
kubectl get svc -n monitoring

# Access using Node IP + NodePort
# Application: http://<NODE_IP>:30080/api/v1/student
# Grafana:     http://<NODE_IP>:30300

# For Kind cluster (localhost maps to node)
curl http://localhost:30080/api/v1/student
```

#### Port-Forward Commands (Alternative)

If NodePort is not working properly or you prefer port-forward:

```bash
# Application (access at http://localhost:8080)
kubectl port-forward svc/student-app 8080:8080 -n student-app

# Grafana (access at http://localhost:3000)
kubectl port-forward svc/grafana 3000:3000 -n monitoring

# Prometheus (access at http://localhost:9090)
kubectl port-forward svc/prometheus 9090:9090 -n monitoring

# Loki (access at http://localhost:3100)
kubectl port-forward svc/loki 3100:3100 -n monitoring
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/student` | List all students |
| GET | `/api/v1/student/{id}` | Get student by ID |
| POST | `/api/v1/student` | Create student |
| PUT | `/api/v1/student/{id}?name=&email=` | Update student |
| DELETE | `/api/v1/student/{id}` | Delete student |
| GET | `/actuator/health` | Health check |

### Example Requests

```bash
# Create
curl -X POST http://localhost:30080/api/v1/student \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice Smith", "email": "alice@example.com", "dob": "1990-03-15"}'

# Read
curl http://localhost:30080/api/v1/student

# Update
curl -X PUT "http://localhost:30080/api/v1/student/1?email=alice.new@example.com"

# Delete
curl -X DELETE http://localhost:30080/api/v1/student/1
```

## Observability

### Accessing Grafana Dashboard

| Environment | URL | Credentials |
|-------------|-----|-------------|
| Kind (local) | [http://localhost:3000](http://localhost:3000) | admin / admin123 |
| AWS EKS | `kubectl get svc grafana -n monitoring` | admin / admin123 |

### Dashboard Features

Pre-configured dashboard includes:

- Application logs with level filtering (ERROR, WARN, INFO)
- CPU/Memory usage per pod
- Log volume over time

### Import Custom Dashboard from JSON

To import an existing Grafana dashboard JSON file as a ConfigMap:

```bash
# Create ConfigMap from dashboard JSON file
kubectl create configmap grafana-custom-dashboard \
  --from-file=my-dashboard.json=./dashboard/Student_App_Dashboard.json \
  -n monitoring

# Verify ConfigMap was created
kubectl get configmap grafana-custom-dashboard -n monitoring

# If Grafana is already running, restart it to load the new dashboard
kubectl rollout restart deployment grafana -n monitoring
```

> **Note:** Ensure your Grafana deployment has a dashboard provider configured to load dashboards from ConfigMaps.

### Prometheus Queries

```promql
# CPU usage by pod (%)
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="student-app", container="student-app"}[5m])) * 100

# Memory usage by pod (MB)
sum by (pod) (container_memory_working_set_bytes{namespace="student-app", container="student-app"}) / 1024 / 1024
```

## Configuration Reference

### Resource Limits

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 250m | 500m |
| Memory | 256Mi | 512Mi |

### Environment Variables

| Variable | Description | Source |
|----------|-------------|--------|
| `SPRING_DATASOURCE_URL` | JDBC connection string | Secret |
| `SPRING_DATASOURCE_USERNAME` | Database username | Secret |
| `SPRING_DATASOURCE_PASSWORD` | Database password | Secret |

### Health Probes

| Probe | Endpoint | Initial Delay | Period | Timeout |
|-------|----------|---------------|--------|---------|
| Readiness | `/api/v1/student` | 60s | 10s | 5s |
| Liveness | `/api/v1/student` | 90s | 30s | 5s |

## Scaling Configuration

### HPA (Horizontal Pod Autoscaler)

| Setting | Value |
|---------|-------|
| Min Replicas | 2 |
| Max Replicas | 10 |
| CPU Target | 70% |
| Memory Target | 80% |

### Scaling Behavior

**Scale Up:**

- No stabilization window (immediate response)
- Can add 100% more pods or 4 pods per 15 seconds

**Scale Down:**

- 60 second stabilization window (prevents flapping)
- Removes max 50% of pods per 60 seconds

### Prerequisites for HPA

HPA requires metrics-server to be installed:

```bash
# Kind cluster
kubectl apply -f kind/metrics_server_components.yaml

# Verify metrics are available
kubectl top pods -n student-app
```

### Load Testing

```bash
# Install load testing tool
go install github.com/rakyll/hey@latest

# Run load test (3 min, 40 concurrent)
hey -z 3m -c 40 http://localhost:30080/api/v1/student

# Watch scaling in real-time
kubectl get hpa -n student-app -w
```

## Security

### Container Security

- **Non-root execution**: Application runs as non-root user in container
- **Minimal base image**: Uses `eclipse-temurin:21-jre-alpine` (reduced attack surface)
- **Multi-stage build**: Build tools not included in final image

### Secrets Management

- Database credentials stored in Kubernetes Secrets
- Secrets injected as environment variables (not mounted files)
- Secrets not committed to git (use `.gitignore`)

### Dockerfile Security Features

| Feature | Implementation | Benefit |
|---------|---------------|---------|
| Multi-stage build | `FROM ... AS builder` → `FROM ...` | Build tools not in final image |
| Non-root user | `adduser` + `USER appuser` | Prevents privilege escalation |
| Alpine base | `eclipse-temurin:21-jre-alpine` | Minimal attack surface (~200MB) |
| Health check | `HEALTHCHECK` instruction | Container-level health monitoring |
| JVM container support | `-XX:+UseContainerSupport` | Respects container memory limits |

### Dockerfile Example

```dockerfile
# Stage 1: Build
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
RUN apk add --no-cache maven
COPY app/ .
RUN mvn clean package -DskipTests

# Stage 2: Runtime
FROM eclipse-temurin:21-jre-alpine

# Security: Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

# Copy JAR with correct ownership
COPY --from=builder --chown=appuser:appgroup /app/target/*.jar app.jar

# Security: Run as non-root user
USER appuser

# Container health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

EXPOSE 8080

# JVM container-aware settings
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
```

## Troubleshooting

```bash
# Check pod status
kubectl get pods -n student-app
kubectl logs -f deployment/student-app -n student-app

# Check HPA metrics
kubectl top pods -n student-app
kubectl describe hpa -n student-app

# Check Loki labels
curl -G http://localhost:3100/loki/api/v1/label/pod/values | jq
```

---

## AWS Deployment

### Configure AWS RDS Secret

**Option A: Use existing YAML file**:

```bash
kubectl apply -f k8s/application_aws/student_app_secret_aws_rds.yaml
```

**Option B: Create manually via CLI**:

```bash
kubectl create namespace student-app

kubectl create secret generic app-secret \
  --namespace student-app \
  --from-literal=SPRING_DATASOURCE_URL="jdbc:postgresql://<RDS_ENDPOINT>:5432/student" \
  --from-literal=SPRING_DATASOURCE_USERNAME="<DB_USERNAME>" \
  --from-literal=SPRING_DATASOURCE_PASSWORD="<DB_PASSWORD>"
```

> Replace `<RDS_ENDPOINT>`, `<DB_USERNAME>`, and `<DB_PASSWORD>` with your AWS RDS values.

> For full AWS EKS/RDS deployment instructions, see [aws/eks/README.md](aws/eks/README.md).

### AWS Infrastructure with Terraform

The `aws/eks/` directory contains Terraform configuration for:

| Resource | Description |
|----------|-------------|
| **VPC** | Custom VPC with public and database subnets |
| **EKS** | Managed Kubernetes cluster with node groups |
| **RDS** | PostgreSQL database in private subnet |

```bash
cd aws/eks

# Initialize Terraform
terraform init

# Plan infrastructure
terraform plan -var="rds_enabled=true" -var="eks_enabled=true" -var="rds_password=<YOUR_PASSWORD>"

# Apply infrastructure
terraform apply -var="rds_enabled=true" -var="eks_enabled=true" -var="rds_password=<YOUR_PASSWORD>"
```

### State Management Recommendations

For production environments, avoid local Terraform state. Use a remote backend:

#### Option A: Terraform Cloud (Recommended for teams)

```hcl
# Add to main.tf
terraform {
  cloud {
    organization = "your-org"
    workspaces {
      name = "aws-kubernetes-lab"
    }
  }
}
```

Benefits:

- Free for up to 500 resources/month
- Built-in state locking and versioning
- VCS integration (GitHub, GitLab)
- Run history and audit logs

#### Option B: Spacelift (Advanced CI/CD)

```hcl
# Add to main.tf
terraform {
  backend "s3" {
    bucket = "your-spacelift-state-bucket"
    key    = "aws-kubernetes-lab/terraform.tfstate"
    region = "eu-central-1"
  }
}
```

Benefits:

- Advanced policy-as-code (Open Policy Agent)
- Drift detection
- Stack dependencies management
- Better for complex multi-stack environments

#### Option C: S3 Backend (AWS-native)

```hcl
# Add to main.tf
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "aws-kubernetes-lab/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

| Feature | Terraform Cloud | Spacelift | S3 Backend |
|---------|-----------------|-----------|------------|
| State Management | ✅ | ✅ | ✅ |
| State Locking | ✅ | ✅ | ✅ (DynamoDB) |
| VCS Integration | ✅ | ✅ | ❌ |
| Policy-as-Code | Basic | Advanced | ❌ |
| Cost | Free tier | Paid | AWS costs only |

---

## Troubleshooting for app

```bash
# Check pod status
kubectl get pods -n student-app
kubectl logs -f deployment/student-app -n student-app

# Check HPA metrics
kubectl top pods -n student-app
kubectl describe hpa -n student-app

# Check Loki labels
curl -G http://localhost:3100/loki/api/v1/label/pod/values | jq
```

---

## Known Limitations & Future Improvements

### Current Limitations

| Limitation | Description |
|------------|-------------|
| **Single Region** | Current setup is single-region; Aurora Global Database would require additional configuration |
| **No TLS/HTTPS** | Application endpoints are HTTP only; production would need ingress with TLS termination |
| **Basic Secrets** | Uses Kubernetes Secrets; production should use AWS Secrets Manager or HashiCorp Vault |
| **Loki Storage** | Uses `emptyDir`; production should use persistent volumes or S3 backend |
| **Grafana Auth** | Basic auth only; production should use OAuth2/OIDC |

### Future Improvements

- [ ] Add Terraform/CloudFormation for **full infrastructure as code**
- [ ] Implement GitOps with **ArgoCD** or Flux
- [ ] Add distributed tracing with Jaeger or AWS X-Ray
- [ ] Configure **AWS Secrets Manager** integration
- [ ] Add network policies for pod-to-pod security
- [ ] Implement blue/green or canary deployments
- [ ] Add PodDisruptionBudget for high availability

---

## License

This project is provided for educational and evaluation purposes.
