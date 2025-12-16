# AWS EKS Infrastructure

Terraform configuration for deploying EKS cluster with RDS PostgreSQL.

## Architecture

```text
┌────────────────────────────────────────────────────────────────────────────────────┐
│                                   AWS Cloud                                        │
│                                                                                    │
│  ┌───────────────────────────────────────────────────────────────────────────────┐ │
│  │                              VPC (172.31.0.0.0/16)                            │ │
│  │                                                                               │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │ │
│  │  │   Public Subnets (172.31.0.0/20, 172.31.16.0/20, 172.32.0.0/20)         │  │ │
│  │  │                                                                         │  │ │
│  │  │  ┌────────────────┐                                                     │  │ │
│  │  │  │Internet Gateway│                                                     │  │ │
│  │  │  └───────┬────────┘                                                     │  │ │
│  │  │          │                                                              │  │ │
│  │  │  ┌───────┴──────────────────────────────────────────────────────────┐   │  │ │
│  │  │  │                      Amazon EKS Cluster                          │   │  │ │
│  │  │  │                                                                  │   │  │ │
│  │  │  │  ┌─────────────────────┐    ┌────────────────────────────────┐   │   │  │ │
│  │  │  │  │ Namespace:          │    │ Namespace: monitoring          │   │   │  │ │
│  │  │  │  │ student-app         │    │                                │   │   │  │ │
│  │  │  │  │                     │    │ ┌───────┐ ┌─────┐ ┌─────────┐  │   │   │  │ │
│  │  │  │  │  ┌─────────────┐    │    │ │Grafana│ │Loki │ │Prometh. │  │   │   │  │ │
│  │  │  │  │  │ Student App │    │    │ └───────┘ └─────┘ └─────────┘  │   │   │  │ │
│  │  │  │  │  │ (2-10 pods) │    │    └────────────────────────────────┘   │   │  │ │
│  │  │  │  │  └──────┬──────┘    │                                         │   │  │ │
│  │  │  │  │  ┌──────┴──────┐    │    ┌────────────────────────────────┐   │   │  │ │
│  │  │  │  │  │     HPA     │    │    │  EKS Managed Node Group        │   │   │  │ │
│  │  │  │  │  └─────────────┘    │    │  (EC2 Instances)               │   │   │  │ │
│  │  │  │  └─────────────────────┘    └────────────────────────────────┘   │   │  │ │
│  │  │  └──────────────────────────────────────────────────────────────────┘   │  │ │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │ │
│  │                                          │                                    │ │
│  │  ┌───────────────────────────────────────┼─────────────────────────────────┐  │ │
│  │  │   atabase Subnets (172.31.96.0/20, 172.31.112.0/20, 172.31.128.0/20)    │  │ │
│  │  │                                       │                                 │  │ │
│  │  │  ┌────────────────────────────────────┴──────────────────────────────┐  │  │ │
│  │  │  │                     Amazon RDS PostgreSQL                         │  │  │ │
│  │  │  │                       (db.t3.micro)                               │  │  │ │
│  │  │  │                                                                   │  │  │ │
│  │  │  │   Endpoint: rdsdemo.xxxxx.eu-central-1.rds.amazonaws.com:5432     │  │  │ │
│  │  │  └───────────────────────────────────────────────────────────────────┘  │  │ │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                               │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────┘
```

> **Note:** NAT Gateway is not created by default. EKS nodes are in public subnets with direct internet access.

## Prerequisites

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | eu-central-1 | AWS region |
| `cluster_name` | eksdemo | EKS cluster name |
| `eks_enabled` | false | Enable EKS deployment |
| `rds_enabled` | false | Enable RDS deployment |
| `rds_username` | dbadmin | RDS master username |
| `rds_password` | - | RDS master password (required) |

## Deploy

```bash
# Initialize
terraform init

# Deploy VPC + RDS
terraform apply -var="rds_enabled=true" -var="rds_password=<YOUR_PASSWORD>"

# Deploy VPC + RDS + EKS
terraform apply -var="rds_enabled=true" -var="eks_enabled=true" -var="rds_password=<YOUR_PASSWORD>"
```

## Outputs

| Output | Description |
|--------|-------------|
| `eks_cluster_endpoint` | EKS API endpoint |
| `eks_cluster_name` | EKS cluster name |
| `rds_endpoint` | RDS PostgreSQL endpoint |

## Connect to EKS

```bash
aws eks update-kubeconfig --region eu-central-1 --name eksdemo
kubectl get nodes
```

## Deploy Application

### 1. Configure RDS Secret

**Option A: Use existing YAML file**:

```bash
# Update the RDS endpoint in the file first
kubectl apply -f ../../k8s/application_aws/student_app_secret_aws_rds.yaml
```

**Option B: Create manually via CLI**:

```bash
kubectl create namespace student-app

kubectl create secret generic app-secret \
  --namespace student-app \
  --from-literal=SPRING_DATASOURCE_URL="jdbc:postgresql://<RDS_ENDPOINT>:5432/student" \
  --from-literal=SPRING_DATASOURCE_USERNAME="dbadmin" \
  --from-literal=SPRING_DATASOURCE_PASSWORD="<YOUR_PASSWORD>"
```

### 2. Deploy Application & Monitoring

```bash
# Deploy application (use application_aws manifests or application with updated image)
kubectl apply -f ../../k8s/application/namespace.yaml
kubectl apply -f ../../k8s/application/student_app_deployment.yaml
kubectl apply -f ../../k8s/application/student_app_service.yaml
kubectl apply -f ../../k8s/application/student_app_hpa.yaml

# Deploy monitoring stack
kubectl apply -f ../../k8s/monitoring/
```

### 3. Access Services

#### Option A: LoadBalancer Service (Default)

```bash
# Get application LoadBalancer URL
kubectl get svc -n student-app

# Get Grafana URL
kubectl get svc grafana -n monitoring
```

#### Option B: NodePort Service

If using NodePort instead of LoadBalancer:

```bash
# Get Node public IP
kubectl get nodes -o wide
# Use the EXTERNAL-IP column

# Or get EC2 instance public IP from AWS CLI
aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=eksdemo" \
  --query 'Reservations[].Instances[].PublicIpAddress' \
  --output text

# Get NodePort for services
kubectl get svc -n student-app
kubectl get svc -n monitoring

# Access using: http://<NODE_PUBLIC_IP>:<NodePort>
```

#### Option C: Port-Forward (For Testing)

```bash
# Application (access at http://localhost:8080)
kubectl port-forward svc/student-app 8080:8080 -n student-app

# Grafana (access at http://localhost:3000)
kubectl port-forward svc/grafana 3000:3000 -n monitoring
```

### 4. Test API

#### With LoadBalancer

```bash
APP_URL=$(kubectl get svc student-app -n student-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Health check
curl http://${APP_URL}/actuator/health

# List students
curl http://${APP_URL}/api/v1/student

# Create student
curl -X POST http://${APP_URL}/api/v1/student \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice Smith", "email": "alice@example.com", "dob": "1990-03-15"}'
```

#### With NodePort

```bash
# Get node public IP and NodePort
NODE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=eksdemo" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)
NODE_PORT=$(kubectl get svc student-app -n student-app -o jsonpath='{.spec.ports[0].nodePort}')

# Health check
curl http://${NODE_IP}:${NODE_PORT}/actuator/health

# List students
curl http://${NODE_IP}:${NODE_PORT}/api/v1/student

# Create student
curl -X POST http://${NODE_IP}:${NODE_PORT}/api/v1/student \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice Smith", "email": "alice@example.com", "dob": "1990-03-15"}'
```

> **Note:** For NodePort to work, ensure the EKS node security group allows inbound traffic on the NodePort range (30000-32767).

## Cleanup

```bash
terraform destroy -var="rds_password=<YOUR_PASSWORD>"
```
