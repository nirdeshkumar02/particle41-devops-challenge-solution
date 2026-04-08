# SimpleTimeService — Particle41 DevOps Challenge

A minimal microservice that returns the current timestamp and the visitor's IP address, containerised and deployed to AWS EKS via Terraform.

---

## What It Does

```
GET /
```

```json
{
  "timestamp": "2026-04-08 14:32:10",
  "ip": "203.0.113.45"
}
```

---

## Repository Structure

```
.
├── app/
│   ├── main.py            # FastAPI microservice
│   ├── requirements.txt   # Pinned dependencies
│   └── Dockerfile         # Multi-stage Alpine build, non-root user
└── terraform/
    ├── modules/
    │   ├── vpc/            # VPC, subnets, IGW, NAT Gateway, S3 endpoint
    │   ├── security_groups/ # Cluster and node security groups
    │   ├── iam/            # EKS cluster and node IAM roles
    │   ├── eks/            # EKS cluster, OIDC provider, node group
    │   ├── irsa/           # IAM Roles for Service Accounts (IRSA)
    │   └── addons/         # VPC CNI, CoreDNS, kube-proxy, Metrics Server, LB Controller, Cluster Autoscaler
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── locals.tf
    ├── versions.tf         # Provider versions + S3 backend config
    └── terraform.tfvars    # Default values
```

---

## Architecture

```
Internet
    │
    ▼
Application Load Balancer        (public subnets — us-east-1a, us-east-1b)
    │
    ▼
EKS Worker Nodes (private subnets)
    │
    ▼
NAT Gateway → Internet           (outbound only — image pulls, AWS API calls)
```

**Why EKS on AWS?**

EKS with managed node groups gives full control over pod scheduling, node-level autoscaling, and is representative of what production teams run day-to-day. The ALB in public subnets terminates all inbound internet traffic; worker nodes have no public IPs and are only reachable through the load balancer. A single NAT Gateway handles all outbound traffic from both private subnets, with an S3 VPC Gateway Endpoint to avoid NAT charges on ECR image pulls.

---

## Part 1 — Running the App Locally

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) >= 24.x

### With Docker

```bash
cd app

docker build -t simpletimeservice:latest .

docker run -d --name simpletimeservice -p 8080:8080 simpletimeservice:latest

curl http://localhost:8080
# {"timestamp":"...","ip":"..."}

# Verify the container runs as a non-root user
docker exec simpletimeservice whoami
# nirdesh

docker stop simpletimeservice && docker rm simpletimeservice
```

### Without Docker

```bash
cd app
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8080
curl http://localhost:8080
```

### Public Image

The image is published to DockerHub and can be pulled directly:

```bash
docker pull nirdeshkumar02/simpletimeservice:latest
```

---

## Part 2 — Deploying to AWS with Terraform

### Prerequisites

| Tool | Version | Install |
|---|---|---|
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | >= 2.x | `brew install awscli` |
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.6.0 | `brew install terraform` |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | >= 1.29 | `brew install kubectl` |

### AWS Credentials

Configure your AWS credentials before running Terraform:

```bash
aws configure
```

Or export them as environment variables:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

The IAM principal needs permissions to create and manage: EKS, VPC, EC2, IAM, S3, and CloudWatch resources.

### Terraform State Backend (Prerequisite)

Terraform state is stored in S3. Before running, create an S3 bucket in your AWS account:

```bash
aws s3api create-bucket \
  --bucket <your-bucket-name> \
  --region us-east-1

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
  bucket = "<your-bucket-name>"   # <-- update this
  ...
}
```

### Variables

Open `terraform/terraform.tfvars` and adjust as needed. Key variables:

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region |
| `node_instance_type` | `m7i-flex.large` | EC2 type for worker nodes |
| `node_min_size` | `2` | Minimum nodes |
| `node_max_size` | `5` | Maximum nodes (Cluster Autoscaler) |
| `cluster_version` | `1.34` | Kubernetes version |

> For a cost-sensitive or personal account, change `node_instance_type` to `t3.medium`.

### Deploy

```bash
cd terraform

terraform init

terraform plan

terraform apply
```

Full deployment takes approximately 15–20 minutes. EKS cluster provisioning is the longest step.

### After Deploy

Configure `kubectl` using the output from Terraform:

```bash
# The exact command is printed as a Terraform output
aws eks update-kubeconfig --region us-east-1 --name particle41-production-cluster --alias particle41-production

kubectl get nodes
```

### Teardown

```bash
terraform destroy
```

---

## CI/CD Pipeline

A GitHub Actions workflow at `.github/workflows/build-and-push.yml` runs automatically on pull requests and releases.

| Event | Jobs |
|---|---|
| Pull request to `main` | Build image → run container → test API response → verify non-root user |
| GitHub Release published | All of the above → push multi-arch image to DockerHub |

```
build-and-test ──► push (on release only)
```

### Required GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` | Your DockerHub username |
| `DOCKERHUB_TOKEN` | DockerHub Personal Access Token |
| `AWS_ACCESS_KEY_ID` | IAM access key for Terraform |
| `AWS_SECRET_ACCESS_KEY` | IAM secret key for Terraform |

### Triggering a Release

```bash
gh release create v1.0.0 --title "v1.0.0" --notes "Initial release"
```

---

## Extra Credit

| Feature | Implementation |
|---|---|
| Non-root container | `USER nirdesh` (UID 1001) in Dockerfile |
| Multi-arch image | Built for `linux/amd64` and `linux/arm64` |
| Remote Terraform state | S3 backend with encryption and native locking |
| IRSA | Fine-grained IAM roles per workload via OIDC |
| Cluster Autoscaler | Scales nodes 2 → 5 based on pending pods |
| AWS Load Balancer Controller | Provisions ALBs from Kubernetes Ingress resources |
| CI/CD pipeline | GitHub Actions — build, test, and push on release |
| S3 VPC Gateway Endpoint | ECR image pulls bypass NAT Gateway (free) |
