#!/bin/bash
# scripts/deploy.sh
# Runs ON the EC2 instance (invoked remotely by Jenkins over SSH).
# Pulls the freshly-pushed image and does a zero-downtime-ish restart.

set -euo pipefail

IMAGE_TAG="${IMAGE_TAG:-latest}"
DOCKERHUB_USER="${DOCKERHUB_USER:-yourdockerhubuser}"
IMAGE="${DOCKERHUB_USER}/myapp:${IMAGE_TAG}"
CONTAINER_NAME="myapp"
OLD_CONTAINER_NAME="myapp_old"

echo ">> Pulling image: ${IMAGE}"
docker pull "${IMAGE}"

# Rename currently running container (if any) so we can roll back on failure
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo ">> Renaming current container to ${OLD_CONTAINER_NAME} as a rollback point"
    docker rename "${CONTAINER_NAME}" "${OLD_CONTAINER_NAME}" || true
    docker stop "${OLD_CONTAINER_NAME}" || true
fi

echo ">> Starting new container"
docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    -p 5000:5000 \
    -e APP_VERSION="${IMAGE_TAG}" \
    "${IMAGE}"

echo ">> Waiting for health check..."
ATTEMPTS=0
until curl -sf http://localhost:5000/health > /dev/null; do
    ATTEMPTS=$((ATTEMPTS+1))
    if [ "$ATTEMPTS" -ge 10 ]; then
        echo "!! New container failed health check. Rolling back."
        docker stop "${CONTAINER_NAME}" || true
        docker rm "${CONTAINER_NAME}" || true
        if docker ps -a --format '{{.Names}}' | grep -q "^${OLD_CONTAINER_NAME}$"; then
            docker rename "${OLD_CONTAINER_NAME}" "${CONTAINER_NAME}"
            docker start "${CONTAINER_NAME}"
        fi
        exit 1
    fi
    sleep 3
done

echo ">> New container healthy. Removing old container."
docker rm "${OLD_CONTAINER_NAME}" 2>/dev/null || true

# Clean up dangling images to save disk space on EC2
docker image prune -f

echo ">> Deployment complete: ${IMAGE}"
