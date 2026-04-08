# SimpleTimeService — Particle41 DevOps Challenge

A production-hardened microservice that returns the current timestamp and the visitor's IP address,
containerised with Docker and deployed to AWS ECS Fargate via Terraform.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture Diagram](#2-architecture-diagram)
3. [Architecture Decision: Why ECS Fargate](#3-architecture-decision-why-ecs-fargate)
4. [Prerequisites](#4-prerequisites)
5. [AWS Authentication](#5-aws-authentication)
6. [Terraform Backend Bootstrap](#6-terraform-backend-bootstrap)
7. [Deployment Instructions](#7-deployment-instructions)
8. [Verify the Application](#8-verify-the-application)
9. [Running the App Locally](#9-running-the-app-locally)
10. [GitHub Actions CI/CD Setup](#10-github-actions-cicd-setup)
11. [Terraform Variables Reference](#11-terraform-variables-reference)
12. [Extra Credit Features](#12-extra-credit-features)
13. [Future Enhancements](#13-future-enhancements)
14. [Cleanup](#14-cleanup)

---

## 1. Project Overview

SimpleTimeService is a minimal HTTP microservice built with **FastAPI** and **uvicorn**
on **Python 3.12-alpine**. It exposes two endpoints: `GET /` returns a
JSON object with the current timestamp (ISO 8601, server local time) and the caller's IP
address — extracted from the `X-Forwarded-For` header set by the ALB, falling back to the
direct connection address when the header is absent. `GET /health` returns a fixed `{"status":"ok"}`
used by the ALB target group and the container's built-in `HEALTHCHECK` instruction.
The container runs as a non-root user (`nirdesh`, UID 1000) and is published to DockerHub as
`nirdeshkumar02/simpletimeservice`.

### Repository Structure

```
.
├── app/
│   ├── main.py            # FastAPI application — GET / and GET /health
│   ├── requirements.txt   # fastapi==0.115.12, uvicorn==0.34.2
│   └── Dockerfile         # Multi-stage build, non-root user, HEALTHCHECK
├── terraform/
│   ├── backend.tf         # S3 remote state — dev-nird-tf-bucket
│   ├── providers.tf       # AWS provider ~> 5.80, Terraform >= 1.6.0
│   ├── main.tf            # Root module — VPC, ALB, IAM, ECS wired together
│   ├── locals.tf          # Derived names: particle41-production, -cluster
│   ├── variables.tf       # 18 input variables with descriptions and defaults
│   ├── terraform.tfvars   # Concrete values used for this deployment
│   ├── outputs.tf         # app_url, vpc_id, ecs_cluster_name, log_group_name…
│   └── modules/
│       └── ecs/           # Local module: ECS cluster, task definition, service, autoscaling
├── .github/
│   ├── actions/
│   │   └── docker-setup/      # Composite: Buildx + optional DockerHub login
│   └── workflows/
│       └── docker-publish.yml # CI/CD pipeline
└── docs/
    └── architecture.svg   # Architecture diagram (this file)
```

### API Response

```
GET /
```
```json
{ "timestamp": "2026-04-08T09:02:15.123456", "ip": "203.0.113.45" }
```

```
GET /health
```
```json
{ "status": "ok" }
```

> The `timestamp` field is an ISO 8601 string in the container's local time (UTC on ECS Fargate).
> No timezone offset is appended because `datetime.now()` returns a naive datetime object.

---

## 2. Architecture Diagram

![Architecture Diagram](docs/architecture.png)

**Traffic flow in plain English:**
A browser or curl request hits the internet-facing ALB (`particle41-production-alb`) on port 80.
The ALB selects one of the two ECS Fargate task replicas running in the private subnets
(one per AZ for high availability) and forwards the request to port 8080 on the chosen task.
The `simpletimeservice` container processes the request, reads the `X-Forwarded-For` header
injected by the ALB, and returns the JSON response. Inside each task, the `log_router`
Fluent Bit sidecar intercepts the application's stdout via FireLens and routes it to
CloudWatch Logs at `/ecs/particle41-production`. The tasks have no public IPs; any outbound
traffic (ECR image pulls, CloudWatch API calls) leaves via the single NAT Gateway.

> **Note — HTTP only:** The ALB listener is currently configured for HTTP on port 80.
> HTTPS requires an ACM certificate tied to a domain you own, an HTTPS listener on port 443,
> and an HTTP → HTTPS redirect rule. See [Section 13 — Future Enhancements](#13-future-enhancements)
> for the full upgrade path.

---

## 3. Architecture Decision: Why ECS Fargate

SimpleTimeService is a single stateless microservice that has one functional endpoint (`GET /`),
no database, no persistent storage, no inter-service communication, and a tiny resource footprint:
the task is allocated only **256 CPU units (0.25 vCPU)** and **512 MiB of memory** in total.
It needs to scale automatically from **1 to 5 tasks** based on CPU or memory pressure (target: 60%),
with a 60-second scale-out cooldown. ECS Fargate is the right tool for exactly this shape of workload.

### Why ECS Fargate fits SimpleTimeService specifically

| Requirement | How Fargate delivers it |
|---|---|
| Serverless containers — no OS to manage | AWS manages the host compute layer entirely; there are no EC2 nodes to patch, rotate, or size |
| Right-sized cost | You pay only for 256 CPU units and 512 MiB while tasks are running — idle capacity costs nothing |
| Native ALB integration | The ALB target group registers task IPs directly (target type `ip`) — no extra ingress controller |
| Native CloudWatch integration | FireLens + `awsfirelens` log driver route logs without an agent sidecar on the host |
| Native IAM integration | Per-task IAM roles (execution role + task role) need no OIDC or service-account wiring |
| Automatic health replacement | The ECS service controller replaces failed tasks using the same `GET /health` check the ALB uses |
| Deployment safety | The circuit breaker (`enable = true, rollback = true`) automatically reverts a bad deployment to the previous task definition |

### Why NOT EKS for this workload

- **Disproportionate cost:** The EKS control plane alone costs $0.10/hr (~$72/month) — more than
  the application compute itself for a service that uses only 0.25 vCPU.
- **Unnecessary complexity:** Running a single-endpoint service on EKS requires the ALB Ingress
  Controller, CoreDNS, kube-proxy, a CNI plugin, node group lifecycle management, and IRSA
  configuration for IAM. None of these add value here.
- **Wrong use case:** Kubernetes shines when you need pod scheduling policies, custom operators,
  horizontal pod autoscalers across dozens of services, or a multi-tenant platform. SimpleTimeService
  is one container.

### Why NOT VM + Docker (EC2) for this workload

- **Manual OS lifecycle:** Running Docker on EC2 requires patching the host OS, managing Docker
  daemon upgrades, and handling node replacement — all to serve one container.
- **No native task recovery:** If the container crashes, recovery requires systemd units or Docker
  restart policies manually configured; there is no service controller watching task health.
- **Coarse autoscaling:** ASG scales EC2 instances, not containers — slower (3–5 min) and
  wasteful (you pay for a full VM to run one task).
- **Security surface:** An SSH-accessible host is a lateral-movement risk; Fargate has no
  persistent host OS to access.

---

## 4. Prerequisites

You need the following tools installed on your local machine before deploying.

---

**Terraform v1.6.0 or higher**
Used to provision all AWS infrastructure declaratively — VPC, ECS, ALB, IAM, CloudWatch.
→ Download: https://developer.hashicorp.com/terraform/install
→ Verify: `terraform version`

---

**AWS CLI v2**
Used to configure AWS credentials so Terraform can authenticate to your AWS account.
→ Download: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
→ Verify: `aws --version`

---

**Docker v24 or higher**
Used to build and push the SimpleTimeService container image locally (optional — the image
is already published to DockerHub; Docker is only needed if you modify the application code).
→ Download: https://docs.docker.com/engine/install/
→ Verify: `docker --version`

---

**Git**
Used to clone this repository.
→ Download: https://git-scm.com/downloads
→ Verify: `git --version`

---

## 5. AWS Authentication

Terraform reads AWS credentials from the environment. Configure one of the following methods
before running any `terraform` commands.

---

**Option A — AWS CLI named profile (recommended for local development)**

This stores credentials in `~/.aws/credentials` and `~/.aws/config` so they persist across
terminal sessions.

```bash
aws configure
# You will be prompted for four values:
#   AWS Access Key ID:     <your-access-key-id>
#   AWS Secret Access Key: <your-secret-access-key>
#   Default region name:   us-east-1
#   Default output format: json
```

Verify the identity Terraform will use:

```bash
aws sts get-caller-identity
```

---

**Option B — Environment variables**

Use this when you cannot persist credentials to disk (e.g. a CI runner without a secrets manager).
The variables are read by the AWS provider automatically.

```bash
export AWS_ACCESS_KEY_ID="<your-access-key-id>"
export AWS_SECRET_ACCESS_KEY="<your-secret-access-key>"
export AWS_DEFAULT_REGION="us-east-1"
```

Verify:

```bash
aws sts get-caller-identity
```

---

**Option C — AWS IAM Identity Center (SSO)**

Use this if your organisation manages access through AWS IAM Identity Center (formerly AWS SSO).
With SSO, your company's administrator grants you a role — no long-lived access keys are created
or stored. Sessions expire automatically (typically 8–12 hours) and must be renewed with a
browser login.

> **If you are an individual developer without an SSO portal, use Option A or B instead.**

**Step 1 — Add an SSO profile to `~/.aws/config`** (your admin will provide the values
for `sso_start_url`, `sso_account_id`, and `sso_role_name`):

```ini
[profile particle41-dev]
sso_session      = particle41-session
sso_account_id   = 123456789012
sso_role_name    = DeployerRole
region           = us-east-1
output           = json

[sso-session particle41-session]
sso_start_url    = https://particle41.awsapps.com/start
sso_region       = us-east-1
sso_registration_scopes = sso:account:access
```

**Step 2 — Log in via the SSO portal** (opens a browser tab to approve the session):

```bash
aws sso login --profile particle41-dev
```

**Step 3 — Export the profile so Terraform picks it up automatically:**

```bash
export AWS_PROFILE=particle41-dev
```

Verify the active identity:

```bash
aws sts get-caller-identity --profile particle41-dev
```

> **Session expiry:** SSO tokens expire. If Terraform returns an authentication error hours
> later, re-run `aws sso login --profile particle41-dev` and re-export `AWS_PROFILE`.

---

**Minimum IAM permissions required** (for whichever method you choose):

```
AmazonECS_FullAccess
AmazonVPCFullAccess
ElasticLoadBalancingFullAccess
IAMFullAccess
AmazonS3FullAccess
CloudWatchLogsFullAccess
AmazonEC2ContainerRegistryReadOnly
```

---

## 6. Terraform Backend Bootstrap

This is a **one-time setup** performed before the first `terraform init`. The Terraform state
is stored remotely in S3 with native locking (`use_lockfile = true`) — no DynamoDB table is
needed. The bucket must exist before Terraform can initialise.

S3 bucket names are globally unique across all AWS accounts, so you must choose your own name.
Once chosen, replace every occurrence of `<your-unique-bucket-name>` below with your chosen name,
and update the `bucket` value in `terraform/backend.tf` to match.

```bash
# 1. Create the S3 bucket for Terraform state
#    The region must match the region in terraform/backend.tf (us-east-1)
aws s3api create-bucket \
  --bucket <your-unique-bucket-name> \
  --region us-east-1

# 2. Enable versioning — lets you roll back to a previous state if apply goes wrong
aws s3api put-bucket-versioning \
  --bucket <your-unique-bucket-name> \
  --versioning-configuration Status=Enabled

# 3. Enable server-side encryption — state files can contain sensitive resource IDs
aws s3api put-bucket-encryption \
  --bucket <your-unique-bucket-name> \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# 4. Block all public access — state files must never be publicly readable
aws s3api put-public-access-block \
  --bucket <your-unique-bucket-name> \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,\
     BlockPublicPolicy=true,RestrictPublicBuckets=true"

# 5. Update terraform/backend.tf with your bucket name, then verify the change
sed -i '' 's/bucket = ".*"/bucket = "<your-unique-bucket-name>"/' terraform/backend.tf
grep 'bucket' terraform/backend.tf
```

Once the bucket exists, proceed to the Deployment Instructions below.

> **Skip S3 altogether:** If you want a quick local deployment without the bootstrap,
> remove the `backend "s3" { ... }` block from `terraform/backend.tf` entirely.
> Terraform will write state to a local `terraform.tfstate` file instead.

---

## 7. Deployment Instructions

### Step 1 — Clone the repository

```bash
git clone https://github.com/nirdeshkumar02/particle41-devops-challenge.git
cd particle41-devops-challenge
```

### Step 2 — Review and update `terraform/backend.tf`

Open `terraform/backend.tf` and confirm the `bucket` value matches the bucket you created
in the Bootstrap section above. Everything else in this file can stay as-is.

```hcl
backend "s3" {
  bucket       = "<your-unique-bucket-name>"   # ← set this to your bucket
  key          = "ecs/particle41/terraform.tfstate"
  region       = "us-east-1"
  encrypt      = true
  use_lockfile = true
}
```

### Step 3 — Review `terraform/terraform.tfvars`

All variables have sensible defaults. The file is fully annotated below — change any value
before deploying if needed. The most common change is `container_image` if you want to deploy
your own image instead of the pre-built one.

```hcl
# AWS region where all resources will be created
aws_region  = "us-east-1"

# These three values are combined to name every resource: particle41-production-<resource>
project     = "particle41"
environment = "production"
owner       = "nirdesh"

# Billing tag applied to all resources — useful for cost allocation reports
cost_center = "engineering"

# VPC and subnet layout — /16 VPC split into /20 slices per AZ
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20"]   # ALB + NAT Gateway
private_subnet_cidrs = ["10.0.128.0/20", "10.0.144.0/20"] # ECS tasks (no public IPs)

# Container image to deploy — update this tag when you push a new version
container_image   = "nirdeshkumar02/simpletimeservice:0.0.4"
container_port    = 8080          # uvicorn listens on this port
health_check_path = "/health"     # ALB and container HEALTHCHECK both hit this path

# Fargate task sizing: 256 CPU units = 0.25 vCPU; 512 MiB total memory
task_cpu      = 256
task_memory   = 512

# Start with 2 replicas (one per AZ); autoscaling adjusts between min and max
desired_count = 2
min_capacity  = 1
max_capacity  = 5

# Scale out when either metric exceeds 60% utilisation; scale in when it drops below
cpu_scale_threshold    = 60
memory_scale_threshold = 60

# CloudWatch log retention — increase for longer audit trails, reduce for cost savings
log_retention_days = 7
```

### Step 4 — Initialise Terraform

This downloads the AWS provider (`~> 5.80`) and four community modules from the Terraform
Registry: `vpc`, `security-group`, `iam`, and `alb`. Run this once per checkout and again
any time you change provider or module versions.

```bash
cd terraform
terraform init
```

Look for this line to confirm success:

```
Terraform has been successfully initialized!
```

### Step 5 — Preview the changes

This shows exactly what Terraform will create without touching any AWS resources. Review
the output to confirm nothing unexpected will be created or destroyed.

```bash
terraform plan
```

Look for the summary at the end of the output:

```
Plan: 42 to add, 0 to change, 0 to destroy.
```

> A fresh deployment creates approximately 42 resources: VPC + subnets + routing + NAT
> Gateway, two security groups, two IAM roles, an ALB with listener and target group, an
> ECS cluster, task definition, service, auto-scaling policies, and a CloudWatch log group.

### Step 6 — Deploy the infrastructure

```bash
terraform apply
```

Terraform will print the full plan again and prompt you to confirm:

```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

Type `yes` and press Enter. Deployment takes approximately **5–8 minutes** — most of the
time is spent waiting for the ALB and NAT Gateway to become active.

> **Automation tip:** In a CI/CD pipeline where you have already reviewed `terraform plan`,
> you can skip the confirmation prompt with `terraform apply -auto-approve`. Do **not** use
> this flag interactively — you will not get a chance to review what will be destroyed or
> changed before it happens.

### Step 7 — Retrieve the application URL

After `apply` completes, Terraform prints all outputs automatically. To retrieve the URL
at any time afterwards:

```bash
terraform output app_url
```

Example output:

```
"http://particle41-production-alb-1234567890.us-east-1.elb.amazonaws.com"
```

All available outputs:

```bash
terraform output
```

```
app_url               = "http://particle41-production-alb-<id>.us-east-1.elb.amazonaws.com"
aws_account_id        = "123456789012"
ecs_cluster_name      = "particle41-production-cluster"
ecs_service_name      = "particle41-production"
log_group_name        = "/ecs/particle41-production"
nat_gateway_public_ip = "54.x.x.x"
vpc_id                = "vpc-xxxxxxxxxxxxxxxxx"
```

---

## 8. Verify the Application

> **Note:** ECS tasks take ~30–60 seconds to pass health checks after `apply`. If you receive
> an HTTP 503 immediately, wait 30 seconds and retry.

```bash
# Capture the URL from the Terraform output (run from inside the terraform/ directory)
APP_URL=$(terraform output -raw app_url)
echo "App URL: $APP_URL"
```

```bash
# Test the main endpoint — should return timestamp and your IP
curl -s "$APP_URL/" | python3 -m json.tool
```

Expected response:

```json
{
    "timestamp": "2026-04-08T09:02:15.123456",
    "ip": "203.0.113.45"
}
```

```bash
# Test the health endpoint — used by the ALB and container HEALTHCHECK
curl -s "$APP_URL/health"
```

Expected response:

```json
{"status":"ok"}
```

```bash
# Confirm both Fargate task replicas are running (desired=2 by default)
aws ecs describe-services \
  --cluster particle41-production-cluster \
  --services particle41-production \
  --region us-east-1 \
  --query 'services[0].{running:runningCount,desired:desiredCount,status:status}'
```

Expected output:

```json
{
    "running": 2,
    "desired": 2,
    "status": "ACTIVE"
}
```

---

## 9. Running the App Locally

You do not need Terraform or an AWS account to run SimpleTimeService locally.

**Build and run from source:**

```bash
# Step 1 — Build the Docker image from the multi-stage Dockerfile
cd app
docker build -t simpletimeservice:local .
```

```bash
# Step 2 — Run the container, exposing port 8080 on your machine
docker run -d --name simpletimeservice -p 8080:8080 simpletimeservice:local
```

```bash
# Step 3 — Test both endpoints
curl http://localhost:8080/
curl http://localhost:8080/health
```

```bash
# Step 4 — Verify the container is NOT running as root
docker exec simpletimeservice whoami
# Expected output: nirdesh
```

```bash
# Step 5 — Clean up
docker stop simpletimeservice && docker rm simpletimeservice
```

**Pull the pre-built image from DockerHub (no build required):**

```bash
docker pull nirdeshkumar02/simpletimeservice:latest
docker run -d --name simpletimeservice -p 8080:8080 nirdeshkumar02/simpletimeservice:latest
```

### Docker Image Details

| Property | Value |
|---|---|
| Base image | `python:3.12-alpine` (both builder and final stage) |
| Build strategy | Multi-stage — pip installs into `/install` in the builder; only `/install` and `main.py` are copied to the final stage |
| Non-root user | `nirdesh` (UID 1000), created with `adduser -D -u 1000` |
| Working directory | `/app` — `chmod 700`; `main.py` is `chmod 600` |
| Exposed port | `8080` |
| Healthcheck | `wget -qO /dev/null http://localhost:8080/health` every 30s, timeout 5s, 3 retries, 10s start period |
| Entrypoint | `uvicorn main:app --host 0.0.0.0 --port 8080` |
| Published platforms | `linux/amd64`, `linux/arm64` |

---

## 10. GitHub Actions CI/CD Setup

The pipeline lives in [.github/workflows/docker-publish.yml](.github/workflows/docker-publish.yml).
It uses a reusable composite action — [docker-setup](.github/actions/docker-setup/action.yml)
— to avoid duplicating Buildx setup and DockerHub login across the three jobs.

### One-time Setup: Add Repository Secrets

The workflow reads two secrets at runtime. These must be added to your GitHub repository
before the pipeline can push images.

**Step 1 — Create a DockerHub Personal Access Token:**
1. Log in at [hub.docker.com](https://hub.docker.com)
2. Click your avatar → **Account Settings** → **Security** → **New Access Token**
3. Give it a description (e.g. `github-actions`) and set permissions to **Read, Write, Delete**
4. Copy the generated token — it is shown only once

**Step 2 — Add the secrets to your GitHub repository:**
1. Open your repository on GitHub
2. Click **Settings** (top navigation bar)
3. In the left sidebar click **Secrets and variables** → **Actions**
4. Click **New repository secret** and add each secret below:

| Secret name (exact, case-sensitive) | Value |
|---|---|
| `DOCKERHUB_USERNAME` | Your DockerHub username — e.g. `nirdeshkumar02` |
| `DOCKERHUB_TOKEN` | The Personal Access Token you copied in Step 1 |

### When the Pipeline Triggers

The workflow file declares `paths: ['app/**']` for push and pull_request events, meaning
the pipeline only runs when files inside the `app/` directory change. Changing only Terraform
files does **not** trigger a build.

| Event | Path filter | Jobs that run | Tags pushed to DockerHub |
|---|---|---|---|
| Pull request to `main` | `app/**` | `build-and-test` only | None — CI gates without publishing |
| Push to `main` | `app/**` | `build-and-test` → `push-main` | `:<7-char-git-sha>` (e.g. `:a3f92c1`) |
| GitHub Release published | *(any file)* | `build-and-test` → `push-release` | `:<semver>` **and** `:latest` |

### What the `build-and-test` Job Validates

Every pipeline run — including PRs — must pass these three checks before any image is pushed:

1. **API response check** — `curl http://localhost:8080/` output must contain both `timestamp` and `ip`
2. **Health check** — `curl http://localhost:8080/health` output must contain `"ok"`
3. **Non-root enforcement** — `docker exec simpletimeservice whoami` must return `nirdesh`
   (the pipeline fails with exit 1 if it returns `root`)

### Verifying a Pipeline Run

1. Open your repository on GitHub
2. Click the **Actions** tab
3. Click the workflow run named **Build and Push**
4. Expand each job (`build-and-test`, `push-main` or `push-release`) to see per-step logs
5. After a successful `push-main` run, confirm the image on DockerHub:

```bash
docker pull nirdeshkumar02/simpletimeservice:<7-char-sha>
docker inspect nirdeshkumar02/simpletimeservice:<7-char-sha> | grep -A2 '"User"'
# Expected: "User": "1000"
```

### Creating a Versioned Release

Use date-based or semantic versioning. Both methods push `:<version>` **and** `:latest` to DockerHub.

```bash
# Option A — date-based versioning (good for regular releases)
git tag -a "v$(date +%Y.%m.%d)" -m "Release $(date +%Y.%m.%d)"
git push origin "v$(date +%Y.%m.%d)"

# Option B — semantic versioning (good for feature milestones)
git tag -a v1.0.0 -m "Initial production release"
git push origin v1.0.0
```

After the tag is pushed, GitHub automatically detects it and — if you also create a GitHub
Release from it — the `push-release` job fires. To create the Release from the CLI:

```bash
# Creates the GitHub Release from the existing tag, triggering the CI/CD pipeline
gh release create v1.0.0 --title "v1.0.0" --notes "Initial production release"
```

The resulting DockerHub tags for a `v1.0.0` release:

```
nirdeshkumar02/simpletimeservice:1.0.0   ← version tag (stripped of 'v' prefix)
nirdeshkumar02/simpletimeservice:latest  ← floating latest pointer
```

> Every image pushed by the pipeline is built for both `linux/amd64` and `linux/arm64`,
> so it runs natively on Intel/AMD servers and Apple Silicon (M1/M2/M3) without emulation.

---

## 11. Terraform Variables Reference

All variables are declared in [terraform/variables.tf](terraform/variables.tf).
The values below are from [terraform/terraform.tfvars](terraform/terraform.tfvars) —
edit that file to customise your deployment.

| Variable | Value in tfvars | Description |
|---|---|---|
| `aws_region` | `"us-east-1"` | AWS region for all resources |
| `project` | `"particle41"` | Project name — prefixed to every resource name |
| `environment` | `"production"` | Deployment environment — appended after project |
| `owner` | `"nirdesh"` | Owner tag applied to all resources |
| `cost_center` | `"engineering"` | Cost center tag for billing |
| `vpc_cidr` | `"10.0.0.0/16"` | CIDR block for the VPC |
| `availability_zones` | `["us-east-1a", "us-east-1b"]` | Exactly 2 AZs required |
| `public_subnet_cidrs` | `["10.0.0.0/20", "10.0.16.0/20"]` | Public subnets — ALB and NAT Gateway |
| `private_subnet_cidrs` | `["10.0.128.0/20", "10.0.144.0/20"]` | Private subnets — ECS tasks |
| `container_image` | `"nirdeshkumar02/simpletimeservice:0.0.4"` | Full image reference including tag |
| `container_port` | `8080` | Port the container listens on |
| `health_check_path` | `"/health"` | HTTP path for ALB and container health checks |
| `task_cpu` | `256` | Total task CPU (256 units = 0.25 vCPU) |
| `task_memory` | `512` | Total task memory in MiB |
| `desired_count` | `2` | Initial ECS task replica count |
| `min_capacity` | `1` | Autoscaling floor |
| `max_capacity` | `5` | Autoscaling ceiling |
| `cpu_scale_threshold` | `60` | CPU % that triggers scale-out |
| `memory_scale_threshold` | `60` | Memory % that triggers scale-out |
| `log_retention_days` | `7` | CloudWatch log retention in days |

To override any value without editing the file:

```bash
terraform apply -var="desired_count=3" -var="max_capacity=10"
```

---

## 12. Extra Credit Features

Each entry below lists: the feature, where it is implemented (file · resource name), the
exact configuration values in use, and whether it was a specified challenge extra credit
item or an additional production enhancement.

---

**Remote S3 backend with state locking** — *Challenge extra credit*
- **File:** `terraform/backend.tf` · **Block:** `terraform { backend "s3" { ... } }`
- **Config:** `bucket = "dev-nird-tf-bucket"`, `key = "ecs/particle41/terraform.tfstate"`,
  `region = "us-east-1"`, `encrypt = true`, `use_lockfile = true`
- Uses native S3 object locking — no DynamoDB table required. Versioning and AES-256
  encryption are bootstrapped separately via the AWS CLI (see Section 6).

---

**Fluent Bit sidecar via FireLens** — *Challenge extra credit*
- **File:** `terraform/modules/ecs/main.tf` · **Resource:** `aws_ecs_task_definition.app`
- **Config:** second container named `log_router`, image
  `public.ecr.aws/aws-observability/aws-for-fluent-bit:stable`,
  `firelensConfiguration = { type = "fluentbit" }`, `essential = false`
- The app container uses `logDriver: awsfirelens` with `Name = "cloudwatch"`,
  `log_group_name = "/ecs/particle41-production"`, `log_stream_prefix = "app/"`.
  The app container declares `dependsOn = [{ containerName = "log_router", condition = "START" }]`
  so Fluent Bit is guaranteed to be running before the app emits its first log line.

---

**CPU and memory auto-scaling** — *Challenge extra credit*
- **File:** `terraform/modules/ecs/main.tf`
- **Resources:** `aws_appautoscaling_target.ecs`, `aws_appautoscaling_policy.scale_out_cpu`,
  `aws_appautoscaling_policy.scale_out_memory`
- **Config:** `min_capacity = 1`, `max_capacity = 5`; both policies use
  `policy_type = "TargetTrackingScaling"` with `target_value = 60`;
  `scale_out_cooldown = 60` seconds, `scale_in_cooldown = 300` seconds;
  metrics: `ECSServiceAverageCPUUtilization` and `ECSServiceAverageMemoryUtilization`

---

**ALB health checks** — *Challenge extra credit*
- **File:** `terraform/main.tf` · **Resource:** `module "alb"` target group `"ecs-app"`
- **Config:** `path = "/health"`, `protocol = "HTTP"`, `port = "traffic-port"`,
  `healthy_threshold = 2`, `unhealthy_threshold = 3`, `interval = 30`, `timeout = 5`,
  `matcher = "200"`

---

**Deployment circuit breaker with automatic rollback** — *Challenge extra credit (production hardening)*
- **File:** `terraform/modules/ecs/main.tf` · **Resource:** `aws_ecs_service.app`
- **Config:** `deployment_circuit_breaker { enable = true, rollback = true }`
- If a new task definition fails to reach a healthy state, ECS automatically reverts the
  service to the last known-good task definition without manual intervention.

---

**GitHub Actions CI/CD pipeline** — *Challenge extra credit*
- **File:** `.github/workflows/docker-publish.yml`
- Three jobs: `build-and-test` (every push/PR), `push-main` (merges to `main`),
  `push-release` (GitHub Releases)
- Path filter `app/**` prevents unnecessary runs when only Terraform files change
- Multi-arch builds: `platforms: linux/amd64,linux/arm64` via `docker/build-push-action@v6`
- Reusable composite action `.github/actions/docker-setup/` avoids duplicating Buildx
  setup and DockerHub login across all three jobs

---

**Hard and soft container resource limits** — *Additional production enhancement*
- **File:** `terraform/modules/ecs/main.tf` · **Resource:** `aws_ecs_task_definition.app`
- **App container:** `cpu = 192`, `memory = 384` (hard — OOM kill threshold),
  `memoryReservation = 256` (soft — scheduler placement hint)
- **Fluent Bit sidecar:** `cpu = 64`, `memory = 128` (hard), `memoryReservation = 64` (soft)
- Task total: `cpu = 256` units, `memory = 512` MiB — prevents either container from
  starving the other by reserving a guaranteed share for each

---

**Container Insights on ECS cluster** — *Additional production enhancement*
- **File:** `terraform/modules/ecs/main.tf` · **Resource:** `aws_ecs_cluster.this`
- **Config:** `setting { name = "containerInsights", value = "enabled" }`
- Surfaces per-task CPU, memory, network, and storage metrics in CloudWatch at no extra
  infrastructure cost — useful for tuning `cpu_scale_threshold` after deployment

---

**Multi-stage Docker build** — *Additional production enhancement*
- **File:** `app/Dockerfile`
- Builder stage (`FROM python:3.12-alpine AS builder`) installs packages with
  `pip install --no-cache-dir --prefix=/install`; the final stage copies only
  `/install` and `main.py` — no pip binary, no build cache, no `.pyc` files ship
  to production
- Non-root user `nirdesh` (UID 1000) created with `adduser -D -u 1000 -s /bin/sh`;
  `/app` is `chmod 700`; `main.py` is `chmod 600`

---

**Container-level health check in Dockerfile** — *Additional production enhancement*
- **File:** `app/Dockerfile`
- **Config:** `HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3`
  `CMD wget -qO /dev/null http://localhost:8080/health || exit 1`
- Mirrors the ALB health check exactly so both the container engine and the load balancer
  agree on liveness. The ECS task definition repeats this check via `healthCheck.command`
  in `terraform/modules/ecs/main.tf`.

---

## 13. Future Enhancements

This section documents improvements that would be made before promoting this deployment to
a customer-facing production environment. Nothing here is required by the challenge — they are
recorded to show awareness of what a production-ready system needs beyond the basics.

---

### HTTPS / TLS Termination

**What:** Add an HTTPS listener on port 443 with an ACM-managed certificate, and redirect
all HTTP traffic on port 80 to HTTPS automatically.

**Why the ALB is HTTP-only today:** ACM certificate validation requires a domain you own
(either a DNS CNAME record in Route 53 or an email approval). The challenge evaluator
needs a working URL from `terraform output app_url` without owning a domain, so HTTP is
the pragmatic choice here.

**How to add it:**
1. Register a domain in Route 53 (or delegate an existing domain's NS records to a hosted zone)
2. Request a public certificate via ACM — `aws acm request-certificate --domain-name example.com --validation-method DNS`
3. Add a Route 53 CNAME for DNS validation, wait for status `ISSUED`
4. Replace the ALB `listeners` block in `terraform/main.tf`:

```hcl
listeners = {
  http-redirect = {
    port     = 80
    protocol = "HTTP"
    redirect = {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  https = {
    port            = 443
    protocol        = "HTTPS"
    certificate_arn = "<acm-certificate-arn>"
    forward = {
      target_group_key = "ecs-app"
    }
  }
}
```

5. Update `module "alb_sg"` to allow inbound `443-tcp` alongside `80-tcp`

---

### Custom Domain with Route 53

**What:** Attach a human-readable domain name (e.g. `api.particle41.io`) to the ALB instead
of exposing the raw `*.elb.amazonaws.com` hostname.

**How:**
- Create a Route 53 hosted zone for the domain
- Add an `aws_route53_record` alias resource pointing to `module.alb.dns_name`
- Pair with the HTTPS enhancement above — a bare domain over HTTP is rarely appropriate

---

### OIDC-based AWS Credentials for GitHub Actions

**What:** Replace the static `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets in GitHub
with short-lived tokens obtained via OpenID Connect federation. No long-lived credentials
are stored anywhere.

**Why it matters:** Static IAM user keys never expire, accumulate over time, and are a
common source of credential leaks. OIDC tokens are scoped to a single workflow run and
expire automatically.

**How:**
1. Create an IAM OIDC identity provider for `token.actions.githubusercontent.com`
2. Create an IAM role with a trust policy that allows only your repository's `push` event:
```json
"Condition": {
  "StringEquals": {
    "token.actions.githubusercontent.com:sub":
      "repo:nirdeshkumar02/particle41-devops-challenge:ref:refs/heads/main"
  }
}
```
3. In your workflow, replace static credential env vars with:
```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::<account-id>:role/github-actions-deployer
    aws-region: us-east-1
```

---

### Private ECR Registry (replace DockerHub)

**What:** Push and pull the container image from a private AWS ECR repository instead of
DockerHub.

**Why it matters today:** DockerHub enforces pull rate limits for anonymous and free-tier
users (~100–200 pulls per 6 hours). ECS Fargate tasks starting during a scale-out event
can hit this limit and fail to pull the image. ECR has no rate limit for pulls within the
same AWS account and region, and images never leave the AWS network when pulled on Fargate.

**How:**
1. Add `aws_ecr_repository.simpletimeservice` in Terraform
2. Update the CI/CD workflow to log in to ECR (`aws-actions/amazon-ecr-login`) and push there
3. Change `container_image` in `terraform.tfvars` to the ECR URI

---

### VPC Endpoints for ECR and S3

**What:** Add VPC Gateway and Interface endpoints so that ECS tasks pull images from ECR and
write state to S3 without traversing the NAT Gateway.

**Why it matters:** Every GB of data leaving the private subnets via NAT Gateway costs
$0.045/GB. ECR image pulls on every task start add up. A Gateway endpoint for S3 and
Interface endpoints for `ecr.api` and `ecr.dkr` eliminate that cost entirely and remove
the internet dependency for image pulls.

**How:** Add to the VPC module call in `terraform/main.tf`:
```hcl
enable_s3_endpoint   = true
enable_ecr_api_endpoint      = true
enable_ecr_dkr_endpoint      = true
```

---

### CloudWatch Alarms and Notifications

**What:** Create CloudWatch alarms on the metrics that matter most, with SNS notifications
to an email address or Slack webhook.

**Suggested alarms:**

| Alarm | Metric | Threshold |
|---|---|---|
| High error rate | `HTTPCode_Target_5XX_Count` on the ALB target group | > 10 in 5 min |
| Task crash loop | `RunningTaskCount` on the ECS service | < `desired_count` for 5 min |
| CPU saturation | `ECSServiceAverageCPUUtilization` | > 80% for 10 min |
| Memory pressure | `ECSServiceAverageMemoryUtilization` | > 80% for 10 min |
| ALB unhealthy hosts | `UnHealthyHostCount` on the target group | > 0 for 2 min |

---

### Structured JSON Logging

**What:** Replace uvicorn's plain-text access log format with structured JSON so that
CloudWatch Log Insights can query fields like `status_code`, `response_time_ms`, and
`client_ip` directly.

**How:** Add a custom uvicorn log config to `main.py` using `python-json-logger`, and
update the Dockerfile entrypoint to pass `--log-config log_config.json`. Fluent Bit's
FireLens route already lands the logs in CloudWatch — the only change is the format of
each log record.

---

### Fargate Spot for Cost Reduction

**What:** Run the ECS service on a mix of Fargate On-Demand and Fargate Spot capacity
providers. Spot capacity is up to 70% cheaper and suits a stateless service that can
tolerate a two-minute interruption notice.

**How:** Add a `capacity_provider_strategy` block to `aws_ecs_service.app`:
```hcl
capacity_provider_strategy {
  capacity_provider = "FARGATE_SPOT"
  weight            = 3
  base              = 0
}
capacity_provider_strategy {
  capacity_provider = "FARGATE"
  weight            = 1
  base              = 1   # always keep at least 1 On-Demand task
}
```

---

### Image Vulnerability Scanning in CI

**What:** Add a Trivy scan step to the `build-and-test` job that fails the pipeline if the
image contains any `HIGH` or `CRITICAL` CVEs.

**How:** Insert after the build step in `.github/workflows/docker-publish.yml`:
```yaml
- name: Scan image for vulnerabilities
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: simpletimeservice:test
    format: table
    exit-code: '1'
    severity: HIGH,CRITICAL
```

---

## 14. Cleanup

```bash
# Navigate to the terraform directory
cd terraform/

# Destroy all resources — Terraform will prompt you to type "yes" to confirm
terraform destroy
```


> ⚠️ **WARNING:** This permanently and irreversibly deletes every AWS resource created by
> this project: the VPC, all subnets, the Internet Gateway, the NAT Gateway, both security
> groups, the Application Load Balancer and target group, the ECS cluster
> (`particle41-production-cluster`), the ECS service, the task definition, both IAM roles,
> the CloudWatch log group (`/ecs/particle41-production`), and all auto-scaling policies.
>
> **Estimated monthly savings after destroy: ~$60/month** based on the default
> `terraform.tfvars` configuration — broken down as:
> | Resource | Monthly cost |
> |---|---|
> | NAT Gateway (single, `us-east-1`) | ~$33 |
> | ECS Fargate (2 tasks × 0.25 vCPU + 0.5 GB) | ~$20 |
> | Application Load Balancer | ~$6 |
> | CloudWatch Logs (minimal ingestion) | ~$1 |
> | **Total** | **~$60** |
>
> Costs scale with the `desired_count` variable. With `desired_count = 1` and autoscaling
> holding at minimum, the Fargate line drops to ~$10/month.

The **S3 backend bucket** (`dev-nird-tf-bucket`) is **not** part of this Terraform state and
will **not** be deleted by `terraform destroy` — this is intentional, to protect state history
from accidental deletion. Delete it manually only when you are certain it is no longer needed:

```bash
# Permanently deletes the bucket and all state files inside it — this cannot be undone
aws s3 rb s3://<your-bucket-name> --force
```
