# SimpleTimeService — Particle41 DevOps Challenge

A minimal microservice that returns the current timestamp and the visitor's IP address, containerised and deployed to AWS EKS via Terraform.

---

## What It Does

```
GET /
```
```json
{ "timestamp": "2026-04-08 14:32:10", "ip": "203.0.113.45" }
```

```
GET /health
```
```json
{ "status": "ok" }
```

---

## Repository Structure

```
.
├── app/
│   ├── main.py              # FastAPI microservice
│   ├── requirements.txt     # Pinned dependencies
│   └── Dockerfile           # Multi-stage Alpine build, non-root user
└── terraform/
    ├── modules/
    │   ├── vpc/             # VPC, subnets, IGW, NAT Gateway, S3 endpoint
    │   ├── security_groups/ # Cluster and node security groups
    │   ├── iam/             # EKS cluster and node IAM roles
    │   ├── eks/             # EKS cluster, OIDC provider, node group
    │   ├── irsa/            # IAM Roles for Service Accounts
    │   └── addons/          # VPC CNI, CoreDNS, kube-proxy, Metrics Server, LB Controller, Cluster Autoscaler
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── locals.tf
    ├── versions.tf          # Provider versions + S3 backend config
    └── terraform.tfvars     # Default variable values
```

---

## Architecture

```
                          ┌─────────────────────────────────────────────────────┐
                          │  VPC  10.0.0.0/16          AWS / us-east-1          │
                          │                                                      │
  Internet ──── IGW ────► │  ┌──── us-east-1a ────┐  ┌──── us-east-1b ────┐   │
                          │  │  Public Subnet      │  │  Public Subnet      │   │
                          │  │  10.0.0.0/20        │  │  10.0.16.0/20       │   │
                          │  │  [ ALB ]  [ NAT GW ]│  │  [ ALB ]            │   │
                          │  └─────────────────────┘  └─────────────────────┘   │
                          │           │                                          │
                          │  ┌──── us-east-1a ────┐  ┌──── us-east-1b ────┐   │
                          │  │  Private Subnet     │  │  Private Subnet     │   │
                          │  │  10.0.128.0/20      │  │  10.0.144.0/20      │   │
                          │  │  [ EKS Nodes ]      │  │  [ EKS Nodes ]      │   │
                          │  └─────────────────────┘  └─────────────────────┘   │
                          │           │                                          │
                          │      NAT GW ──► Internet  (image pulls, AWS APIs)   │
                          │      S3 VPC Endpoint      (ECR pulls — free)        │
                          └─────────────────────────────────────────────────────┘
```

| Module | What it creates |
|---|---|
| `vpc` | VPC, 4 subnets (2 public + 2 private across 2 AZs), IGW, NAT Gateway, route tables, S3 VPC endpoint |
| `security_groups` | Cluster SG (nodes → API server :443), Node SG (node-to-node + control plane + all outbound) |
| `iam` | EKS cluster role, node group role with ECR, SSM, and CNI policies |
| `eks` | EKS control plane (K8s 1.34), OIDC provider, managed node group in private subnets (min 2, max 5 nodes) |
| `irsa` | Per-workload IAM roles via OIDC: VPC CNI, LB Controller, Cluster Autoscaler, CloudWatch Agent |
| `addons` | VPC CNI, kube-proxy, CoreDNS (×2), Metrics Server, AWS LB Controller, Cluster Autoscaler |

**Why EKS on AWS?**

EKS with managed node groups reflects what production teams typically run — full control over pod scheduling and node-level autoscaling. The ALB in public subnets terminates all inbound internet traffic; worker nodes have no public IPs. A single NAT Gateway handles outbound traffic from both private subnets, and an S3 VPC Gateway Endpoint routes ECR image pulls over the AWS backbone to avoid NAT charges.

---

## Part 1 — Running the App Locally

### Prerequisite

- [Docker](https://docs.docker.com/get-docker/) >= 24.x

```bash
cd app

docker build -t simpletimeservice:latest .

docker run -d --name simpletimeservice -p 8080:8080 simpletimeservice:latest

curl http://localhost:8080
curl http://localhost:8080/health

docker stop simpletimeservice && docker rm simpletimeservice
```

### Public Image

Each release publishes two tags to DockerHub:

```bash
docker pull nirdeshkumar02/simpletimeservice:latest
docker pull nirdeshkumar02/simpletimeservice:<version>
```

---

## Part 2 — Deploying to AWS with Terraform

### Prerequisites

| Tool | Version | Install |
|---|---|---|
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | >= 2.x | `brew install awscli` |
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.6.0 | `brew install terraform` |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | >= 1.29 | `brew install kubectl` |

### Step 1 — Configure AWS credentials

```bash
aws configure
```

The IAM principal needs permissions to create and manage: EKS, VPC, EC2, IAM, S3, and CloudWatch resources.

### Step 2 — Create an S3 bucket for Terraform state

```bash
aws s3api create-bucket --bucket <your-bucket-name> --region us-east-1

aws s3api put-bucket-versioning \
  --bucket <your-bucket-name> \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket <your-bucket-name> \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

Then update the bucket name in `terraform/versions.tf`:

```hcl
backend "s3" {
  bucket = "<your-bucket-name>"   # update this
  key    = "eks/particle41/terraform.tfstate"
  region = "us-east-1"
  ...
}
```

### Step 3 — Review variables

Key variables in `terraform/terraform.tfvars`:

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region |
| `node_instance_type` | `m7i-flex.large` | EC2 type for worker nodes |
| `node_min_size` | `2` | Minimum nodes |
| `node_max_size` | `5` | Maximum nodes |
| `cluster_version` | `1.34` | Kubernetes version |

> For a cost-sensitive account, change `node_instance_type` to `t3.medium`.

### Step 4 — Deploy

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Deployment takes approximately 15–20 minutes.

### Step 5 — Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name particle41-production-cluster --alias particle41-production

kubectl get nodes
```

### Teardown

```bash
terraform destroy
```

---

## CI/CD Pipeline

A GitHub Actions workflow runs on pull requests and releases.

| Event | What runs |
|---|---|
| Pull request to `main` | Build image → test `/` and `/health` endpoints → verify non-root user |
| GitHub Release published | All of the above → push image to DockerHub as `:<version>` and `:latest` |

### GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` | Your DockerHub username |
| `DOCKERHUB_TOKEN` | DockerHub Personal Access Token |

### Triggering a Release

```bash
gh release create <version> --title "<version>" --notes "Release notes"
```

Example: `gh release create v1.0.0 --title "v1.0.0" --notes "Initial release"`

---

## Extra Credit

| Feature | Implementation |
|---|---|
| Non-root container | Runs as `nirdesh` (UID 1001) |
| Multi-arch image | Built for `linux/amd64` and `linux/arm64` |
| Remote Terraform state | S3 backend with encryption and native locking |
| IRSA | Fine-grained IAM roles per workload via OIDC |
| Cluster Autoscaler | Scales nodes 2 → 5 based on pending pods |
| AWS Load Balancer Controller | Provisions ALBs from Kubernetes Ingress resources |
| CI/CD pipeline | GitHub Actions — build, test, and push on release |
| S3 VPC Gateway Endpoint | ECR image pulls bypass NAT Gateway (free) |
