# SimpleTimeService — Particle41 DevOps Challenge

A minimal microservice that returns the current IST timestamp and the visitor's IP address,
containerised with Docker and deployed to AWS ECS Fargate via Terraform.

---

## 1. Project Overview

```
GET /
```
```json
{ "timestamp": "2026-04-08T14:32:10.123456+05:30", "ip": "203.0.113.45" }
```

```
GET /health
```
```json
{ "status": "ok" }
```

The timestamp is ISO 8601 format in IST (UTC+5:30).
The IP is extracted from the `X-Forwarded-For` header (set by the ALB) with a fallback to the direct client address.

---

## 2. Architecture Diagram

```
                      Internet
                          │
                    ┌─────▼─────┐
                    │    ALB    │  (public subnets, port 80)
                    └─────┬─────┘
                          │
          ┌───────────────┴───────────────┐
          │                               │
   ┌──────▼──────┐                 ┌──────▼──────┐
   │ us-east-1a  │                 │ us-east-1b  │
   │ Private     │                 │ Private     │
   │ Subnet      │                 │ Subnet      │
   │             │                 │             │
   │ ┌─────────┐ │                 │ ┌─────────┐ │
   │ │ECS Task │ │                 │ │ECS Task │ │
   │ │─────────│ │                 │ │─────────│ │
   │ │app :8080│ │                 │ │app :8080│ │
   │ │Fluent   │ │                 │ │Fluent   │ │
   │ │Bit (log)│ │                 │ │Bit (log)│ │
   │ └────┬────┘ │                 │ └────┬────┘ │
   └──────┼──────┘                 └──────┼──────┘
          │                               │
          └──────── NAT Gateway ──────────┘
                          │
               ┌──────────▼──────────┐
               │   CloudWatch Logs   │
               │   /ecs/particle41-* │
               └─────────────────────┘
```

Each ECS task runs two containers:

| Container | Role |
|---|---|
| `simpletimeservice` | FastAPI app — serves `/` and `/health` on port 8080 |
| `log_router` (Fluent Bit) | Sidecar — routes stdout/stderr to CloudWatch Logs via FireLens |

| Terraform Module | What it creates |
|---|---|
| `terraform-aws-modules/vpc` | VPC, 4 subnets (2 public + 2 private across 2 AZs), IGW, single NAT Gateway, route tables |
| `modules/security_groups` | ALB SG (internet → :80), ECS task SG (ALB → container port only) |
| `modules/iam` | ECS task execution role (ECR pull + CloudWatch write), task role (Fluent Bit logs) |
| `modules/alb` | Internet-facing ALB, HTTP listener on :80, target group with `/health` checks |
| `modules/ecs` | ECS cluster with Container Insights, Fargate task definition, ECS service with circuit breaker, CPU/memory autoscaling |

---

## 3. Architecture Decision: Why ECS Fargate

### ECS Fargate vs EKS (Kubernetes)

| Concern | ECS Fargate | EKS |
|---|---|---|
| Operational overhead | None — no nodes, no kubelet, no node upgrades | High — node groups, add-ons, RBAC, CRDs |
| Time to first deploy | ~3–5 min | ~20 min (control plane + node group) |
| Cost at low scale | Pay per task CPU/mem only | ~$0.10/hr control plane + EC2 nodes always on |
| AWS integration | Native — IAM task roles, CloudWatch, ALB, App Autoscaling | Requires IRSA, LB Controller, OIDC setup |
| Right for this workload | ✅ Single stateless service, simple scaling | ❌ Overkill — no inter-service mesh, no custom scheduling |

SimpleTimeService is a single stateless HTTP service. Kubernetes adds value when you need pod scheduling policies, custom operators, or a multi-service ecosystem — none of which apply here. ECS Fargate covers every requirement without the operational overhead.

### ECS Fargate vs VM + Docker (EC2)

| Concern | ECS Fargate | VM + Docker (EC2) |
|---|---|---|
| Node management | None — AWS manages the compute layer | You patch, rotate, and size EC2 instances |
| High availability | Built-in — tasks spread across 2 AZs | Requires manual ASG + ELB wiring |
| Autoscaling | App Autoscaling on CPU/memory — scales tasks | ASG scales VMs, not containers — slower and coarser |
| Security surface | No SSH, no persistent host OS | SSH attack surface, shared host vulnerabilities |
| Failed-task recovery | ECS service controller restarts failed tasks | Requires systemd / Docker restart policies |

Running Docker on EC2 means owning the OS: patching, availability groups, log agent installation, and process supervision — all to run one container. Fargate removes that entirely. A senior engineer's job is to choose the right tool for the job, not the most complex one.

---

## 4. Prerequisites

| Tool | Version | Install |
|---|---|---|
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | >= 2.x | `brew install awscli` |
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.6.0 | `brew install terraform` |
| [Docker](https://docs.docker.com/get-docker/) | >= 24.x | [docs.docker.com](https://docs.docker.com/get-docker/) |
| Git | any | pre-installed on most systems |

---

## 5. AWS Authentication

Configure credentials using any of the following methods:

**Option A — AWS CLI (recommended for local development)**
```bash
aws configure
# Enter: AWS Access Key ID, Secret Access Key, region (us-east-1), output format (json)
```

**Option B — Environment variables**
```bash
export AWS_ACCESS_KEY_ID=<your-key-id>
export AWS_SECRET_ACCESS_KEY=<your-secret>
export AWS_DEFAULT_REGION=us-east-1
```

**Option C — IAM role (recommended for CI/CD)**
Attach an IAM role to your EC2 instance or use OIDC-based federation in GitHub Actions.

**Minimum IAM permissions required:**
`AmazonECS_FullAccess`, `AmazonVPCFullAccess`, `ElasticLoadBalancingFullAccess`,
`IAMFullAccess`, `AmazonS3FullAccess`, `CloudWatchLogsFullAccess`

---

## 6. Terraform Backend Bootstrap

The S3 backend must exist before running `terraform init`. Create it once with:

```bash
# 1. Create the bucket
aws s3api create-bucket \
  --bucket <your-bucket-name> \
  --region us-east-1

# 2. Enable versioning (allows state history and rollback)
aws s3api put-bucket-versioning \
  --bucket <your-bucket-name> \
  --versioning-configuration Status=Enabled

# 3. Enable server-side encryption
aws s3api put-bucket-encryption \
  --bucket <your-bucket-name> \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

Then update the `bucket` value in `terraform/backend.tf`:

```hcl
backend "s3" {
  bucket = "<your-bucket-name>"   # ← change this
  ...
}
```

---

## 7. Deployment Instructions

```bash
# 1. Clone the repository
git clone https://github.com/<your-username>/particle41-devops-challenge.git
cd particle41-devops-challenge

# 2. (Optional) Review and adjust variables
#    Open terraform/terraform.tfvars to change region, image tag, scaling limits, etc.

# 3. Initialise Terraform — downloads providers and the vpc registry module
cd terraform
terraform init

# 4. Preview the changes
terraform plan

# 5. Deploy all infrastructure (~3–5 minutes)
terraform apply

# 6. Note the application URL from Terraform outputs
#    app_url = "http://<alb-dns>.us-east-1.elb.amazonaws.com"
```

---

## 8. Verify the Application

After `terraform apply` completes, test the endpoints:

```bash
# Get the URL from Terraform output
export APP_URL=$(terraform output -raw app_url)

# Test the main endpoint
curl $APP_URL/
# Expected:
# { "timestamp": "2026-04-08T14:32:10.123456+05:30", "ip": "203.0.113.45" }

# Test the health endpoint
curl $APP_URL/health
# Expected:
# { "status": "ok" }
```

> **Note:** ALB DNS propagation can take 1–2 minutes after `apply` completes.

---

## 9. Running the App Locally

```bash
cd app

docker build -t simpletimeservice:latest .

docker run -d --name simpletimeservice -p 8080:8080 simpletimeservice:latest

curl http://localhost:8080
curl http://localhost:8080/health

docker stop simpletimeservice && docker rm simpletimeservice
```

**Public image on DockerHub:**
```bash
docker pull nirdeshkumar02/simpletimeservice:latest
```

---

## 10. GitHub Actions CI/CD Setup

1. Fork or clone this repository to your GitHub account
2. Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Value |
|---|---|
| `DOCKERHUB_USERNAME` | Your DockerHub username |
| `DOCKERHUB_TOKEN` | DockerHub Personal Access Token (read/write) |

**Pipeline behaviour:**

| Event | Jobs that run |
|---|---|
| Pull request to `main` (app/ changes) | `build-and-test` — builds image, tests endpoints, verifies non-root user |
| Push to `main` (app/ changes) | `build-and-test` → `push-main` — pushes `:<short-sha>` + `:latest` |
| GitHub Release published | `build-and-test` → `push-release` — pushes `:<version>` + `:latest` |

**Create a versioned release:**
```bash
gh release create v1.0.0 --title "v1.0.0" --notes "Initial release"
# Publishes: nirdeshkumar02/simpletimeservice:1.0.0 and :latest
```

---

## 11. Extra Credit Features

| Feature | Implementation |
|---|---|
| **Remote S3 backend** | `terraform/backend.tf` — S3 with encryption and native locking (`use_lockfile = true`) |
| **CPU + memory limits (hard & soft)** | App container: `cpu=192`, `memory=384` (hard), `memoryReservation=256` (soft). Fluent Bit: `cpu=64`, `memory=128` (hard), `memoryReservation=64` (soft) |
| **ECS Auto Scaling** | Target tracking on CPU (default 60%) and memory (default 60%); scales 2 → 10 tasks |
| **ALB health checks** | `GET /health`, 200 expected, interval 30s, threshold 2 healthy / 3 unhealthy, timeout 5s |
| **Fluent Bit sidecar** | FireLens log router — routes app stdout/stderr to CloudWatch Logs at `/ecs/<name>` with `app/` stream prefix |
| **GitHub Actions CI/CD** | Push to `main` → build + push `:<sha>` + `:latest`; Release → push `:<version>` + `:latest` |
| **Deployment circuit breaker** | `deployment_circuit_breaker { enable = true, rollback = true }` — auto-rolls back on failed deployment |
| **Container Insights** | ECS cluster-level CPU, memory, and network metrics in CloudWatch |
| **S3 VPC Gateway Endpoint** | ECR image pulls bypass NAT Gateway — saves data transfer cost |
| **Official VPC module** | Uses `terraform-aws-modules/vpc ~> 5.0` from the Terraform Registry |

---

## 12. Cleanup

```bash
cd terraform
terraform destroy
```

> **Warning:** This permanently deletes all AWS resources created by this project, including the VPC,
> ECS cluster, ALB, and all associated networking. The S3 backend bucket is **not** deleted
> (it lives outside the Terraform state). Delete it manually if no longer needed:
> `aws s3 rb s3://<your-bucket-name> --force`
