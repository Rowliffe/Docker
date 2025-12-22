#!/bin/bash

# Variables
DOCKER_USERNAME="Rowliffe"
VERSION="latest"

# Login
echo "🔐 Connexion à Docker Hub..."
docker login

# Créer builder si nécessaire
docker buildx create --name mybuilder --use 2>/dev/null || docker buildx use mybuilder

# Build et push frontend
echo "🚀 Build et push frontend..."
cd frontend
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target production \
  -t ${DOCKER_USERNAME}/exam-docker-v6-frontend:${VERSION} \
  -t ${DOCKER_USERNAME}/exam-docker-v6-frontend:latest \
  --push \
  .

# Build et push backend
echo "🚀 Build et push backend..."
cd ../backend
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target production \
  -t ${DOCKER_USERNAME}/exam-docker-v6-backend:${VERSION} \
  -t ${DOCKER_USERNAME}/exam-docker-v6-backend:latest \
  --push \
  .

echo "✅ Images poussées sur Docker Hub !"
