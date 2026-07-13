#!/bin/bash
set -euo pipefail

DOCKER_IMAGE="${DOCKERHUB_USERNAME:-nayan}/amazon-clone"
EC2_HOST="${EC2_HOST:-}"
EC2_USER="ubuntu"

if [ -z "$EC2_HOST" ]; then
  echo "Usage: EC2_HOST=<ip> ./scripts/deploy.sh"
  echo ""
  echo "Environment variables:"
  echo "  DOCKERHUB_USERNAME  Docker Hub username (default: nayan)"
  echo "  EC2_HOST            EC2 public IP (required)"
  exit 1
fi

echo "=== Building Docker image ==="
docker build -t "$DOCKER_IMAGE":latest .

echo "=== Pushing to Docker Hub ==="
docker push "$DOCKER_IMAGE":latest

echo "=== Deploying to EC2: $EC2_HOST ==="
ssh -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" <<DEPLOY_EOF
  set -e
  cd /home/ubuntu/amazon-clone

  echo "=== Pulling latest code ==="
  git pull origin main

  echo "=== Pulling Docker image ==="
  docker pull $DOCKER_IMAGE:latest

  echo "=== Loading image into Kind ==="
  kind load docker-image $DOCKER_IMAGE:latest --name amazon-clone-cluster

  echo "=== Updating deployment ==="
  cd kubernetes
  sed -i "s|image: .*|image: $DOCKER_IMAGE:latest|" deployment.yaml

  echo "=== Applying manifests ==="
  kubectl apply -f namespace.yaml
  kubectl apply -f deployment.yaml -n amazon-clone
  kubectl apply -f service.yaml -n amazon-clone
  kubectl apply -f ingress.yaml -n amazon-clone

  echo "=== Waiting for rollout ==="
  kubectl rollout status deployment/shopeasy -n amazon-clone --timeout=120s

  echo "=== Verifying ==="
  kubectl get pods -n amazon-clone -o wide
  curl -sf http://localhost/ > /dev/null && echo "Site is UP" || echo "Site is DOWN"
DEPLOY_EOF

echo "=== Done ==="
