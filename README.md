# SimpleTimeService — Particle41 DevOps Challenge

A minimal microservice that returns the current UTC+5:30 timestamp and the visitor's IP address,
containerised and deployed to AWS ECS Fargate via Terraform.

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
└── terraform/               # Run terraform plan / apply from here
    ├── modules/
    │   ├── vpc/             # VPC, subnets, IGW, NAT Gateway, S3 endpoint
    │   ├── security_groups/ # ALB and ECS task security groups
    │   ├── iam/             # ECS task execution role and task role
    │   ├── alb/             # Application Load Balancer, target group, listener
    │   └── ecs/             # ECS cluster, Fargate task definition, service, autoscaling
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── locals.tf
    ├── versions.tf          # Provider versions + backend config
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
                          │  │  [ ECS Fargate ]    │  │  [ ECS Fargate ]    │   │
                          │  └─────────────────────┘  └─────────────────────┘   │
                          │           │                                          │
                          │      NAT GW ──► Internet  (image pulls, AWS APIs)   │
                          │      S3 VPC Endpoint      (ECR pulls — free)        │
                          └─────────────────────────────────────────────────────┘
```

Each ECS task runs two containers:

| Container | Role |
|---|---|
| `simpletimeservice` | FastAPI app — serves `/` and `/health` on port 8080 |
| `log_router` (Fluent Bit) | Sidecar — collects stdout/stderr and ships to CloudWatch Logs |

| Module | What it creates |
|---|---|
| `vpc` | VPC, 4 subnets (2 public + 2 private across 2 AZs), IGW, NAT Gateway, route tables, S3 VPC endpoint |
| `security_groups` | ALB SG (internet → :80), ECS task SG (ALB → :8080 + all outbound) |
| `iam` | ECS task execution role (ECR pull + CloudWatch write), task role (Fluent Bit CloudWatch Logs) |
| `alb` | Internet-facing ALB, listener on :80, target group with `/health` checks |
| `ecs` | ECS cluster with Container Insights, Fargate task definition, ECS service, CPU/memory autoscaling |

---

## Why ECS Fargate — not EKS or VM+Docker

### ECS Fargate vs EKS (Kubernetes)

| Concern | ECS Fargate | EKS |
|---|---|---|
| Operational overhead | None — no nodes, no kubelet, no node upgrades | High — node groups, add-ons, RBAC, CRDs |
| Time to first deploy | ~3–5 min | ~20 min (control plane + node group) |
| Cost at low scale | Pay per task CPU/mem only | ~$0.10/hr control plane + EC2 nodes always on |
| AWS integration | Native — IAM task roles, CloudWatch, ALB, App Autoscaling | Requires IRSA, LB Controller, OIDC setup |
| Right for this workload | ✅ Single stateless service, simple scaling | ❌ Overkill — no inter-service mesh, no custom scheduling |

Kubernetes adds value when you need pod scheduling policies, custom operators, or a multi-service ecosystem. SimpleTimeService is a single stateless HTTP service — ECS Fargate covers every requirement without the operational overhead.

### ECS Fargate vs VM + Docker

| Concern | ECS Fargate | VM + Docker (EC2) |
|---|---|---|
| Node management | None — AWS manages the compute layer | You patch, rotate, and size EC2 instances |
| High availability | Built-in — tasks spread across 2 AZs | Requires manual ASG + ELB wiring |
| Autoscaling | App Autoscaling on CPU/memory — scales tasks | ASG scales VMs, not containers — slower and coarser |
| Security surface | No SSH, no persistent host OS | SSH attack surface, shared host vulnerabilities |
| Failed-task recovery | ECS service controller restarts failed tasks | Requires systemd / Docker restart policies |

Running Docker on EC2 means owning the OS: patching, availability groups, log agent installation, and process supervision — all to run one container. Fargate removes that entirely.

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

The image is published to DockerHub and runs as a non-root user (`nirdesh`, UID 1001):

```bash
docker pull nirdeshkumar02/simpletimeservice:latest
docker pull nirdeshkumar02/simpletimeservice:<version>    # e.g. 1.0.0
```

---

## Part 2 — Deploying to AWS with Terraform

### Prerequisites

| Tool | Version | Install |
|---|---|---|
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | >= 2.x | `brew install awscli` |
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.6.0 | `brew install terraform` |

### Step 1 — Configure AWS credentials

```bash
aws configure
```

The IAM principal needs permissions to create and manage: ECS, VPC, EC2, IAM, ALB, S3, and CloudWatch resources.

### Step 2 — Create an S3 bucket for Terraform remote state

This project uses an S3 backend for Terraform state and locking (extra credit). You must create your own bucket before running `terraform init`.

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

Then update **one line** in `terraform/versions.tf` — replace the bucket name with yours:

```hcl
# terraform/versions.tf
backend "s3" {
  bucket = "<your-bucket-name>"   # ← change this
  ...
}
```

### Step 3 — Review and adjust variables (optional)

Open `terraform/terraform.tfvars` to review defaults. Key variables:

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region |
| `container_image` | `nirdeshkumar02/simpletimeservice:latest` | Image to deploy |
| `task_cpu` | `256` | Fargate task CPU units (256 = 0.25 vCPU) |
| `task_memory` | `512` | Fargate task memory (MiB) |
| `desired_count` | `2` | Initial task replica count |
| `min_capacity` | `2` | Autoscaling minimum |
| `max_capacity` | `10` | Autoscaling maximum |
| `cpu_scale_threshold` | `70` | Scale-out when avg CPU > this % |
| `memory_scale_threshold` | `80` | Scale-out when avg memory > this % |

### Step 4 — Deploy

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Deployment takes approximately 3–5 minutes. At the end, Terraform prints the application URL:

```
Outputs:

app_url = "http://<alb-dns>.us-east-1.elb.amazonaws.com"
```

### Step 5 — Verify

```bash
curl $(terraform output -raw app_url)
curl $(terraform output -raw app_url)/health
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

Image tags follow the `nginx`-style convention — no `v` prefix (e.g. `1.0.0`, not `v1.0.0`).

### GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` | Your DockerHub username |
| `DOCKERHUB_TOKEN` | DockerHub Personal Access Token |

### Triggering a Release

```bash
gh release create v1.0.0 --title "v1.0.0" --notes "Initial release"
# Published to DockerHub as simpletimeservice:1.0.0 and simpletimeservice:latest
```

---

## Extra Credit

| Feature | Implementation |
|---|---|
| Non-root container | Runs as `nirdesh` (UID 1001) — enforced both in Dockerfile and ECS task definition |
| Multi-arch image | Built for `linux/amd64` and `linux/arm64` |
| Remote Terraform state | Optional S3 backend with encryption and native locking (see above) |
| Fargate autoscaling | Scales tasks 2 → 10 based on configurable CPU and memory thresholds |
| Health checks | Container-level health check on `/health`; ALB target group health check |
| Fluent Bit sidecar | Structured log routing to CloudWatch Logs via FireLens |
| Container Insights | ECS cluster-level CPU, memory, and network metrics in CloudWatch |
| CI/CD pipeline | GitHub Actions — build, test, and push on release |
| S3 VPC Gateway Endpoint | ECR image pulls bypass NAT Gateway (free path) |
