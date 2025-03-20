# Overview

<walkthrough-tutorial-duration duration="10"></walkthrough-tutorial-duration>

This tutorial will guide you to deploy the required infrastructure of Falcon Cloud Security on GCP folder.

## Automated Configuration

If you trust on the beauty of automation, you can simply run one of the deployment scripts available on this repository.

## Install Falcon container sensor on GKE

```sh
chmod +x ./install-container-sensor.sh
```

```sh
./install-container-sensor.sh -r <falcon-gcr-repo> -u <falcon-client-id> -s <falcon-client-secret>
```

In case you want to customize or modify any value or parameter, you can follow the along this documentation.

--------------------------------

## Project setup

1. Select the project from the drop-down list.
2. Copy and execute the script below in the Cloud Shell to complete the project setup.

<walkthrough-project-setup></walkthrough-project-setup>

```sh
gcloud config set project <walkthrough-project-id/>
```

## Step 1: Install Falcon Container Sensor

### Set the client ID and secret to variables by replacing it's values below

```sh
export FALCON_CLIENT_ID=<falcon-client-id>
export FALCON_CLIENT_SECRET=<falcon-client-secret>
```

### Collect Falcon Container Image Information

```sh
curl -sSL -o falcon-container-sensor-pull.sh "https://raw.githubusercontent.com/CrowdStrike/falcon-scripts/main/bash/containers/falcon-container-sensor-pull/falcon-container-sensor-pull.sh"
chmod +x falcon-container-sensor-pull.sh
export FALCON_CID=$( ./falcon-container-sensor-pull.sh -t falcon-container --get-cid )
```

### Copy falcon container sensor image to a private registry

Export your Falcon Container Sensor repository

```sh
export FALCON_IMAGE_REPO=<falcon-gcr-repo>
```

```sh
export FALCON_PUSH_IMAGE=$(bash <(curl -Ls https://github.com/CrowdStrike/falcon-scripts/releases/latest/download/falcon-container-sensor-pull.sh) -t falcon-container -c $FALCON_IMAGE_REPO )
export LATESTSENSOR=$(bash <(curl -Ls https://github.com/CrowdStrike/falcon-scripts/releases/latest/download/falcon-container-sensor-pull.sh) -t falcon-container --get-image-path)
export FALCON_IMAGE_TAG=$(echo $LATESTSENSOR | cut -d':' -f 2)
```

### Deploy Falcon Container Sensor using helm

```sh
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm --force-update
helm upgrade --install falcon-helm crowdstrike/falcon-sensor -n falcon-system --create-namespace \
  --set node.enabled=false \
  --set container.enabled=true \
  --set falcon.cid="$FALCON_CID" \
  --set container.image.repository="$FALCON_IMAGE_REPO" \
  --set container.image.tag="$FALCON_IMAGE_TAG" \
  --set falcon.tags="pov-demo-container"
```

--------------------------------

## Step 2: Set up GCP Service Account

### Create the CrowdStike service account

Create a custom Service Account used by Falcon to get access to GCP projects and resources.

```sh
gcloud iam service-accounts create falcon-sensor-registry-access --description="GCP service account to allow Falcon Container Sensor to access private registries" --display-name="CrowdStrike Sensor Registry Access"
```

### Generate a Service Account JSON key grant permissions for Falcon to assume the Service Account

```sh
gcloud iam service-accounts keys create registry-access-key.json --iam-account=falcon-sensor-registry-access@<walkthrough-project-id/>.iam.gserviceaccount.com
```

### Grant the service account Artifact Registry permission

```sh
gcloud projects add-iam-policy-binding <walkthrough-project-id/> \
  --member=serviceAccount:falcon-sensor-registry-access@<walkthrough-project-id/>.iam.gserviceaccount.com \
  --role=roles/artifactregistry.reader
```

--------------------------------

## Step 3: Set up a Kubernetes Secret for Falcon Container Sensor

### Create a kubernetes secrets for falcon container sensor

```sh
kubectl create secret docker-registry falcon-registry-secret \
  --docker-server=<gcp-location>-docker.pkg.dev \
  --docker-username=_json_key \
  --docker-email=falcon-sensor-registry-access@<walkthrough-project-id/>.iam.gserviceaccount.com \
  --docker-password="$(cat registry-access-key.json)" \
  --namespace falcon-system
```

### Create a Cluster Role for Container Sensor service account

```sh
kubectl create clusterrole falcon-registry-secret-reader --verb=get,list --resource=secrets --resource-name=falcon-registry-secret
```

### Bind Falcon Registry Secret Reader Cluster Role to Container Sensor service account

```sh
kubectl create clusterrolebinding falcon-registry-secret-reader --clusterrole=falcon-registry-secret-reader --serviceaccount=falcon-system:crowdstrike-falcon-sa--resource-name=falcon-registry-secret
```

--------------------------------

## Cleanup Environment

### Delete Falcon Container Sensor Deployment

```sh
helm uninstall falcon-helm -n falcon-system
```

### Delete CrowdStrike Service Account

```sh
gcloud iam service-accounts delete falcon-sensor-registry-access@<walkthrough-project-id/>.iam.gserviceaccount.com
```

### Delete the secret on Falcon Container Sensor namespace

```sh
kubectl delete secret falcon-registry-secret -n falcon-system
```

### Delete Cluster Role

```sh
kubectl delete clusterrole falcon-registry-secret-reader 
```

### Delete Cluster Role Binding

```sh
kubectl delete clusterrolebinding falcon-registry-secret-reader
```
