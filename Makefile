DOCKER_IMAGE ?= amazon-clone
KIND_CLUSTER  ?= amazon-clone-cluster
NAMESPACE     ?= amazon-clone

.PHONY: build load deploy port-forward clean

build:
	docker build -t $(DOCKER_IMAGE):latest .

load: build
	kind load docker-image $(DOCKER_IMAGE):latest --name $(KIND_CLUSTER)

deploy: load
	kubectl apply -f kubernetes/namespace.yaml
	@sed "s|\$${DOCKERHUB_USERNAME}/amazon-clone:latest|$(DOCKER_IMAGE):latest|g" \
		kubernetes/deployment.yaml | kubectl apply -f - -n $(NAMESPACE)
	kubectl apply -f kubernetes/service.yaml -n $(NAMESPACE)
	kubectl apply -f kubernetes/ingress.yaml -n $(NAMESPACE)
	kubectl rollout status deployment/shopeasy -n $(NAMESPACE) --timeout=120s
	@echo ""
	@echo "Site: http://localhost (via Ingress)"
	@kubectl get pods -n $(NAMESPACE)

port-forward:
	kubectl port-forward svc/shopeasy 8080:80 -n $(NAMESPACE)
	@echo "Access at http://localhost:8080"

status:
	kubectl get pods,svc,ingress -n $(NAMESPACE)

logs:
	kubectl logs -l app=shopeasy -n $(NAMESPACE) --tail=50 -f

clean:
	kind delete cluster --name $(KIND_CLUSTER)

destroy-infra:
	cd terraform && terraform destroy -auto-approve
