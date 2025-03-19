# Falcon Container Sensor for GKE

This document is intended to help the onboarding process of Falcon Container Sensor deployments as daemonset for Google Kubernetes Engine (GKE) clusters.

## Prerequisites

1. **Install supporting tools**
   - [Google Cloud SDK](https://cloud.google.com/sdk/docs/install-sdk)
   - [Kubectl](https://kubernetes.io/pt-br/docs/reference/kubectl/)
   - [helm](https://helm.sh/)
   - [Docker Installed](https://docs.docker.com/engine/install/)
   - CrowdStrike API key pair
   - A Google Artifact Registry to store Falcon Container image
   - Curl Installed

2. **CrowdStrike Requirements**
   - CrowdStrike API permissions/scopes:
      - Falcon Images Download (Read)
      - Sensor Download (Read)

## Installation

You can start the installation process by clicking on the gcloud button bellow:

| Deployment Type | Link |
|:--| :--|
| **Container Sensor** | [![Bash Deployment](https://gstatic.com/cloudssh/images/open-btn.svg)](https://shell.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https%3A%2F%2Fgithub.com%2Figorschultz%2Ffalcon-container-sensor-gke.git&cloudshell_workspace=gcp&cloudshell_tutorial=docs/install_container_sensor.md) |
