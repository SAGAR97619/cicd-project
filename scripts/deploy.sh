#!/bin/bash

set -e

IMAGE_TAG=${IMAGE_TAG:-latest}
DOCKERHUB_USER=${DOCKERHUB_USER}
IMAGE=${DOCKERHUB_USER}/cicd-project:${IMAGE_TAG}

echo "Pulling latest image..."
docker pull ${IMAGE}

echo "Stopping old container..."
docker stop myapp || true
docker rm myapp || true

echo "Starting new container..."
docker run -d \
    --name myapp \
    --restart unless-stopped \
    -p 5000:5000 \
    -e APP_VERSION=${IMAGE_TAG} \
    ${IMAGE}

echo "Waiting for container..."
sleep 10

echo "Health Check..."
curl -f http://localhost:5000/health

echo "Deployment Completed Successfully."
