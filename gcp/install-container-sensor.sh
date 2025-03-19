#!/bin/bash
set -e

# Function to display usage information
usage() {
    echo "Usage: $0 -r <falcon-gcr-repo> -u <falcon-client-id> -s <falcon-client-secret>"
    echo "  -r: Falcon GCR image repository (required)"
    echo "  -u: CrowdStrike falcon client ID (required)"
    echo "  -s: CrowdStrike falcon client secret (required)"
    exit 1
}

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

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "helm is not installed"
    exit 1
fi

# Check if curl is installed.
if ! command -v curl &> /dev/null; then
    echo "curl could not be found."
    exit 1
fi

# Check if docker is installed.
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker and try again."
    exit 1
fi

# Check if docker daemon is running
if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running"
    exit 1
fi

# Parse command line arguments
while getopts ":r:u:s:" opt; do
    case $opt in
        r) falcon_repo="$OPTARG" ;;
        u) falcon_client_id="$OPTARG" ;;
        s) falcon_client_secret="$OPTARG" ;;
        \?) echo "Invalid option -$OPTARG" >&2; usage ;;
    esac
done

# Initialize variables
FALCON_IMAGE_REPO=$falcon_repo
GCP_PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2> /dev/null)


export FALCON_CLIENT_ID=$falcon_client_id
export FALCON_CLIENT_SECRET=$falcon_client_secret

# Copy falcon container image to a private GCR registry
curl -sSL -o falcon-container-sensor-pull.sh "https://raw.githubusercontent.com/CrowdStrike/falcon-scripts/main/bash/containers/falcon-container-sensor-pull/falcon-container-sensor-pull.sh"
chmod +x falcon-container-sensor-pull.sh

export FALCON_CID=$( ./falcon-container-sensor-pull.sh -t falcon-container --get-cid )
export FALCON_IMAGE=$( ./falcon-container-sensor-pull.sh -t falcon-container -c $FALCON_IMAGE_REPO )
export FALCON_IMAGE_TAG=$( echo $FALCON_IMAGE | cut -d':' -f 2 )

# Deploy Falcon Container Sensor
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm --force-update
helm upgrade --install falcon-helm crowdstrike/falcon-sensor -n falcon-system --create-namespace \
  --set node.enabled=false \
  --set container.enabled=true \
  --set falcon.cid="$FALCON_CID" \
  --set container.image.repository="$FALCON_IMAGE" \
  --set container.image.tag="$FALCON_IMAGE_TAG" \
  --set falcon.tags="pov-demo-container"

# Create a service account for Falcon Container Sensor
gcloud iam service-accounts create falcon-sensor-registry-access --description="GCP service account to allow Falcon Container Sensor to access private registries" --display-name="CrowdStrike Sensor Registry Access"
CROWDSTRIKE_REGISTRY_ACCESS_SA_EMAIL=$(gcloud iam service-accounts list --filter=falcon-sensor-registry-access --format="value(EMAIL)")

# Grant the service account Artifact Registry permissions
gcloud alpha projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member=serviceAccount:$CROWDSTRIKE_REGISTRY_ACCESS_SA_EMAIL \
  --role=roles/artifactregistry.reader

# Create a json key for Falcon Container Sensor SA
gcloud iam service-accounts keys create registry-access-key.json \
  --iam-account $CROWDSTRIKE_REGISTRY_ACCESS_SA_EMAIL

# Get your GCR registry
GCR_REGISTRY=$(echo $FALCON_IMAGE | cut -d/ -f1)

# Create the secret on Falcon Container Sensor namespace
kubectl create secret docker-registry falcon-registry-secret \
  --docker-server=$GCR_REGISTRY \
  --docker-username=_json_key \
  --docker-email=$CROWDSTRIKE_REGISTRY_ACCESS_SA_EMAIL \
  --docker-password="$(cat registry-access-key.json)" \
  --namespace falcon-system

# Create a Cluster Role for Container Sensor SA
kubectl create clusterrole falcon-registry-secret-reader --verb=get,list --resource=secrets --resource-name=falcon-registry-secret

# Bind Falcon Registry Secret Reader Cluster Role to Container Sensor SA
kubectl create clusterrolebinding falcon-registry-secret-reader --clusterrole=falcon-registry-secret-reader --serviceaccount=falcon-system:crowdstrike-falcon-sa
