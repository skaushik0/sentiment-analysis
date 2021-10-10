# Builds the Docker images for "sentiment-analysis", and deploys to GKE.

SHELL           := /bin/bash
.DEFAULT_GOAL   := all
SRC_DIR         := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
PROG_NAME       := cmu-14-848-sa
VERSION         := v0.1

SA_DKR_URL_BASE := skaushik0/14-848-sa
SA_FE_DKR_TAG   := "$(SA_DKR_URL_BASE)-fe:$(VERSION)"
SA_WA_DKR_TAG   := "$(SA_DKR_URL_BASE)-wa:$(VERSION)"
SA_BE_DKR_TAG   := "$(SA_DKR_URL_BASE)-be:$(VERSION)"

SA_SRC_DIR      := $(SRC_DIR)/k8s-mastery
SA_FE_BUILD_DIR := $(SA_SRC_DIR)/sa-frontend
SA_WA_BUILD_DIR := $(SA_SRC_DIR)/sa-webapp
SA_BE_BUILD_DIR := $(SA_SRC_DIR)/sa-logic

GKE_ZONE        := us-east4-a
GKE_MIN_NODES   := 1
GKE_MAX_NODES   := 1
GKE_UTIL_PROF   := optimize-utilization
GKE_MACH_TYPE   := e2-medium
GKE_LABELS      := course=cmu-14-848
GKE_NODE_TAG    := nodes-gp

K8S_DEPLOY_FILE := $(SRC_DIR)/k8s-deploy.yaml
K8S_INGESS_NAME := ingress/sa-ing
K8S_INGRESS_IP  :=
K8S_IP_POLL_CMD := kubectl get $(K8S_INGESS_NAME) -o \
                               jsonpath='{.status.loadBalancer.ingress[0].ip}'



# Build the Docker images.
build:
	docker build -t $(SA_FE_DKR_TAG) $(SA_FE_BUILD_DIR)
	docker build -t $(SA_WA_DKR_TAG) $(SA_WA_BUILD_DIR)
	docker build -t $(SA_BE_DKR_TAG) $(SA_BE_BUILD_DIR)

# Push the Docker images to DockerHub.
# Note(s):
#   - This step needs `docker' to be setup to talk
#     to DockerHub. It can be done via `docker login'.
push:
	docker push $(SA_FE_DKR_TAG)
	docker push $(SA_WA_DKR_TAG)
	docker push $(SA_BE_DKR_TAG)

# Create a Kubernetes cluster on GKE.
# Note(s):
#  - This step needs the `gcloud' binary. After installing,
#    run `gcloud init' to configure access to Google Cloud
#    Platform.
k8s-cluster-create:
	gcloud container clusters create $(PROG_NAME) --labels $(GKE_LABELS)  \
			--machine-type $(GKE_MACH_TYPE) --num-nodes $(GKE_MIN_NODES)  \
			--max-nodes $(GKE_MAX_NODES) --min-nodes $(GKE_MIN_NODES)     \
			--tags $(GKE_NODE_TAG) --autoscaling-profile $(GKE_UTIL_PROF) \
			--zone $(GKE_ZONE)

# Get the `kubeconfig' credentials for the cluster. It will
# be written to "~/.kube/config".
k8s-get-kubeconfig:
	gcloud container clusters get-credentials --zone $(GKE_ZONE) $(PROG_NAME)

# Deploy the web application to Google Kubernetes Engine (GKE).
k8s-deploy:
	kubectl apply -f $(K8S_DEPLOY_FILE)

# The ingress on GKE takes a while to load and get the public IP.
k8s-poll-ingress-ip:
	while [ -z "$(shell $(K8S_IP_POLL_CMD))" ]; do                       \
		echo "Waiting for ingress: $(K8S_INGESS_NAME) to be created..."; \
		sleep 10;                                                        \
	done

# Show the URL to the web-app.
k8s-show:
	@echo "The URL for the web-app is: \"http://$(shell $(K8S_IP_POLL_CMD))\"."
	@echo "Please note that it might take a while for the ingress"
	@echo "to be completely setup; you may see 404s initially, but"
	@echo "it eventually recovers and displays the web-app page."

# Delete resources and the Kubernetes cluster.
k8s-clean:
	kubectl delete -f $(K8S_DEPLOY_FILE)
	gcloud container clusters delete --zone $(GKE_ZONE) $(PROG_NAME)

all: init build push k8s-cluster-create k8s-get-kubeconfig \
	 k8s-deploy k8s-poll-ingress-ip k8s-show

.PHONY: init build push k8s-cluster-create k8s-get-kubeconfig \
	    k8s-deploy k8s-poll-ingress-ip k8s-show clean
