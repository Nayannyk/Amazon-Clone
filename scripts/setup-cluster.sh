#!/bin/bash
set -euo pipefail

CLUSTER_NAME="${1:-amazon-clone-cluster}"
PROJECT_NAME="${2:-amazon-clone}"
NAMESPACE="${3:-amazon-clone}"
REPLICAS="${4:-2}"

echo "=== Waiting for Docker to be ready ==="
while ! docker info > /dev/null 2>&1; do
  echo "Waiting for Docker daemon..."
  sleep 3
done
echo "Docker is ready."

echo "=== Creating Kind cluster config ==="
cat > /tmp/kind-config.yaml <<'KINDEOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
KINDEOF

for i in $(seq 1 "$REPLICAS"); do
  cat >> /tmp/kind-config.yaml <<KINDEOF
- role: worker
KINDEOF
done

echo "=== Creating Kind cluster: $CLUSTER_NAME ==="
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "Cluster $CLUSTER_NAME already exists, deleting..."
  kind delete cluster --name "$CLUSTER_NAME"
fi
kind create cluster --name "$CLUSTER_NAME" --config /tmp/kind-config.yaml
rm -f /tmp/kind-config.yaml

echo "=== Waiting for nodes to be Ready ==="
kubectl wait --for=condition=Ready node --all --timeout=300s
kubectl get nodes -o wide

echo "=== Building Docker image ==="
cd "/home/ubuntu/${PROJECT_NAME}"
docker build -t amazon-clone:latest .

echo "=== Loading image into Kind cluster ==="
kind load docker-image amazon-clone:latest --name "$CLUSTER_NAME"

echo "=== Installing Nginx Ingress Controller for Kind ==="
curl -sL https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/cloud/deploy.yaml \
  | sed 's|image: registry.k8s.io/ingress-nginx/controller:.*|image: registry.k8s.io/ingress-nginx/controller:v1.12.1|' \
  > /tmp/ingress-nginx-deploy.yaml

cat >> /tmp/ingress-nginx-deploy.yaml <<'PATCH'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  template:
    spec:
      nodeSelector:
        ingress-ready: "true"
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          effect: NoSchedule
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
PATCH

kubectl apply -f /tmp/ingress-nginx-deploy.yaml
rm -f /tmp/ingress-nginx-deploy.yaml

echo "=== Waiting for Ingress Controller pod to be ready on control-plane ==="
sleep 15
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo "=== Deploying application ==="
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST_DIR="$(dirname "$SCRIPT_DIR")/kubernetes"

echo "=== Setting local image for initial deploy ==="
sed "s|\${DOCKERHUB_USERNAME}/amazon-clone:latest|amazon-clone:latest|g" \
  "$MANIFEST_DIR/deployment.yaml" > /tmp/deployment-local.yaml

kubectl apply -f "$MANIFEST_DIR/namespace.yaml"
kubectl apply -f /tmp/deployment-local.yaml --namespace="$NAMESPACE"
kubectl apply -f "$MANIFEST_DIR/service.yaml" --namespace="$NAMESPACE"
kubectl apply -f "$MANIFEST_DIR/ingress.yaml" --namespace="$NAMESPACE"
rm -f /tmp/deployment-local.yaml

echo "=== Patching deployment with correct replicas ==="
kubectl scale deployment shopeasy --namespace="$NAMESPACE" --replicas="$REPLICAS"

echo "=== Waiting for deployment to be ready ==="
kubectl rollout status deployment/shopeasy --namespace="$NAMESPACE" --timeout=120s

echo "=== Deployment complete ==="
echo ""
echo "============================================"
echo "  ShopEasy Amazon Clone is deployed!"
echo "============================================"
echo ""
kubectl get pods -n "$NAMESPACE" -o wide
echo ""
kubectl get svc -n "$NAMESPACE"
echo ""
kubectl get ingress -n "$NAMESPACE"
echo ""
echo "Access the website at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo ""
echo "Or use kubectl port-forward from your local machine:"
echo "  kubectl port-forward svc/shopeasy 8080:80 -n $NAMESPACE --kubeconfig <path-to-kubeconfig>"
echo ""
echo "For CI/CD, set these GitHub Secrets:"
echo "  DOCKERHUB_USERNAME  - Docker Hub username"
echo "  DOCKERHUB_TOKEN     - Docker Hub access token"
echo "  EC2_HOST            - This instance's public IP"
echo "  EC2_SSH_KEY         - Private key content from terraform output"
echo "============================================"
