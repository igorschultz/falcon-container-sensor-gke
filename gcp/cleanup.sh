#!/bin/bash

set -e


# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI is not installed"
    echo "Please install gcloud CLI from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="get(account)" 2>/dev/null | grep -q '^'; then
    echo "Error: No active gcloud account found"
    echo "Please authenticate using: gcloud auth login"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl is not installed"
    exit 1
fi

GCP_PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2> /dev/null)

# Uninstall Falcon Container Sensor
helm uninstall falcon-helm -n falcon-system

# Grant the service account Artifact Registry permissions
gcloud projects remove-iam-policy-binding $GCP_PROJECT_ID \
  --member=serviceAccount:falcon-sensor-registry-access@$GCP_PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/artifactregistry.reader

# Delete Falcon Container Sensor service account
gcloud iam service-accounts delete falcon-sensor-registry-access@$GCP_PROJECT_ID.iam.gserviceaccount.com

# Delete the secret on Falcon Container Sensor namespace
kubectl delete secret falcon-registry-secret -n falcon-system

# Delete a Cluster Role
kubectl delete clusterrole falcon-registry-secret-reader 

# Delete Cluster Role Bind 
kubectl delete clusterrolebinding falcon-registry-secret-reader
