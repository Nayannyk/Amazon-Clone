# ShopEasy - Amazon Clone

A static e-commerce website deployed on Kubernetes using Terraform, Kind, and GitHub Actions CI/CD.

## Architecture

```
GitHub Push
    │
    ├── GitHub Actions CI/CD
    │   ├── Build Docker Image
    │   ├── Push to Docker Hub
    │   └── Deploy to EC2 via SSH
    │
    └── AWS EC2 (t2.medium)
        ├── Docker
        ├── Kind Cluster (2 nodes)
        │   ├── Nginx Ingress Controller
        │   └── ShopEasy App (2 replicas)
        └── Website accessible on port 80
```

## Project Structure

```
Amazon-Clone/
├── .github/workflows/
│   └── ci-cd.yml              # GitHub Actions CI/CD pipeline
├── terraform/
│   ├── provider.tf            # AWS, TLS, GitHub providers
│   ├── variables.tf           # All configurable variables
│   ├── main.tf                # VPC, EC2, SG, GitHub secrets
│   ├── outputs.tf             # Public IP, SSH command, etc.
│   ├── user_data.sh           # Installs Docker, kubectl, Kind
│   └── terraform.tfvars.example
├── kubernetes/
│   ├── namespace.yaml         # amazon-clone namespace
│   ├── deployment.yaml        # 2 replicas with probes
│   ├── service.yaml           # ClusterIP service
│   └── ingress.yaml           # Nginx Ingress rule
├── scripts/
│   ├── setup-cluster.sh       # EC2 bootstrap script
│   └── deploy.sh              # Manual deploy script
├── Dockerfile                 # nginx:alpine image
├── nginx.conf                 # Web server config
├── index.html                 # Website
├── Makefile                   # Local dev commands
└── *.jpg *.webp               # Product images
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- [AWS CLI](https://aws.amazon.com/cli/) configured
- [Docker Hub](https://hub.docker.com) account
- [GitHub](https://github.com) account

## Quick Start

### 1. Clone and configure

```bash
git clone https://github.com/your-username/your-repo-name.git
cd your-repo-name/terraform
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit terraform.tfvars

```hcl
aws_region      = "ap-south-1"
instance_type   = "t2.medium"
volume_size     = 20
github_token    = "ghp_xxxxxxxxxxxxxxxxxxxx"  # GitHub token with repo scope
github_repo     = "your-username/your-repo-name"
```

### 3. Deploy infrastructure

```bash
cd terraform
terraform init
terraform apply
```

### 4. Access the website

```bash
# Get the URL from terraform output
terraform output website_url

# Or SSH into EC2
ssh -i generated-key.pem ubuntu@$(terraform output -raw ec2_public_ip)
```

## GitHub Secrets

### Manual Setup (required)

| Secret | Description | Where to create |
|--------|-------------|-----------------|
| `DOCKERHUB_USERNAME` | Docker Hub username | hub.docker.com/settings/security |
| `DOCKERHUB_TOKEN` | Docker Hub access token | hub.docker.com/settings/security |
| `AWS_ACCESS_KEY_ID` | AWS IAM access key | AWS IAM console |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key | AWS IAM console |
| `AWS_REGION` | AWS region | ap-south-1 |

### Auto-created by Terraform

| Secret | Description |
|--------|-------------|
| `EC2_HOST` | EC2 public IP |
| `EC2_SSH_KEY` | SSH private key |

## CI/CD Pipeline

The GitHub Actions workflow runs automatically on push to `main`:

1. **Build Job**
   - Builds Docker image
   - Pushes to Docker Hub with SHA and `latest` tags
   - Uses GitHub Actions cache for faster builds

2. **Deploy Job**
   - Configures AWS on EC2
   - Pulls latest code and Docker image
   - Loads image into Kind cluster
   - Applies Kubernetes manifests
   - Waits for rollout to complete
   - Runs health check with retries

## Local Development

```bash
# Build Docker image
make build

# Build and load into Kind
make load

# Deploy to local Kind cluster
make deploy

# Check status
make status

# View logs
make logs

# Port forward to localhost:8080
make port-forward

# Delete Kind cluster
make clean
```

## Manual Deploy (without CI/CD)

```bash
EC2_HOST=<your-ec2-ip> ./scripts/deploy.sh
```

## Useful Commands

```bash
# SSH into EC2
ssh -i terraform/generated-key.pem ubuntu@$(terraform output -raw ec2_public_ip)

# Check pods
kubectl get pods -n amazon-clone

# Check services
kubectl get svc -n amazon-clone

# Check ingress
kubectl get ingress -n amazon-clone

# View logs
kubectl logs -l app=shopeasy -n amazon-clone -f

# Restart deployment
kubectl rollout restart deployment/shopeasy -n amazon-clone

# Scale replicas
kubectl scale deployment/shopeasy --replicas=3 -n amazon-clone
```

## Tear Down

```bash
# Delete Kind cluster (on EC2)
ssh -i terraform/generated-key.pem ubuntu@$(terraform output -raw ec2_public_ip)
kind delete cluster --name amazon-clone-cluster

# Destroy all AWS resources
cd terraform
terraform destroy
```

## Tech Stack

- **Infrastructure**: Terraform, AWS EC2
- **Container Runtime**: Docker
- **Orchestration**: Kubernetes (Kind)
- **Ingress**: Nginx Ingress Controller
- **CI/CD**: GitHub Actions
- **Registry**: Docker Hub
- **Web Server**: Nginx Alpine
