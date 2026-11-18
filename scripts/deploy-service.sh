#!/bin/bash
# Usage: ./deploy-service.sh <service_name> <image_tag>
# Example: ./deploy-service.sh user-service latest

SERVICE_NAME=$1
IMAGE_TAG=${2:-latest}

if [ -z "$SERVICE_NAME" ]; then
  echo "Error: SERVICE_NAME is required."
  echo "Usage: ./deploy-service.sh <service_name> [image_tag]"
  exit 1
fi

echo "Deploying $SERVICE_NAME with tag $IMAGE_TAG..."

cd ~/infra-backend || exit 1

# Export environment variable for docker compose
export IMAGE_TAG=$IMAGE_TAG

# Pull the specific service's new image
docker compose -f docker-compose.apps.yml pull "$SERVICE_NAME"

# Recreate and restart only that single container without affecting other services
docker compose -f docker-compose.apps.yml up -d --no-deps "$SERVICE_NAME"

# Prune dangling images to free disk space
docker image prune -f

echo "$SERVICE_NAME deployment completed successfully!"
