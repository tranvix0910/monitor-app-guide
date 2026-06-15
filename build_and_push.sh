#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=========================================="
echo "     Docker Build & Push Automation"
echo "=========================================="
echo ""

# --- Registry Selection ---
echo "Select Target Registry:"
echo "1) Docker Hub"
echo "2) Custom Registry"
read -p "Enter your choice (1 or 2): " REGISTRY_CHOICE

if [ "$REGISTRY_CHOICE" == "1" ]; then
    read -p "Enter your Docker Hub username: " DOCKER_USER
    if [ -z "$DOCKER_USER" ]; then
        echo "Error: Docker Hub username cannot be empty!"
        exit 1
    fi
    REGISTRY="docker.io"
    IMAGE_PREFIX="$DOCKER_USER"
elif [ "$REGISTRY_CHOICE" == "2" ]; then
    read -p "Enter Custom Registry URL (e.g., registry.example.com): " CUSTOM_REG
    read -p "Enter Project/Namespace name (e.g., wineapp): " PROJECT_NAME
    if [ -z "$CUSTOM_REG" ] || [ -z "$PROJECT_NAME" ]; then
        echo "Error: Registry URL and Project name cannot be empty!"
        exit 1
    fi
    REGISTRY="$CUSTOM_REG"
    IMAGE_PREFIX="$CUSTOM_REG/$PROJECT_NAME"
else
    echo "Invalid choice. Exiting."
    exit 1
fi

read -p "Enter Image Tag (default 'latest'): " TAG
TAG=${TAG:-latest}

echo ""
# --- Authentication ---
echo "Select Authentication Method for $REGISTRY:"
echo "1) Already logged in (Skip authentication)"
echo "2) Username & Password"
echo "3) Username & Access Token (PAT)"
read -p "Enter your choice (1, 2, or 3): " AUTH_CHOICE

if [[ "$AUTH_CHOICE" == "2" || "$AUTH_CHOICE" == "3" ]]; then
    read -p "Enter Username: " LOGIN_USER
    read -s -p "Enter Password/Token: " LOGIN_PASS
    echo ""
    
    echo "Logging into $REGISTRY..."
    if [ "$REGISTRY_CHOICE" == "1" ]; then
        echo "$LOGIN_PASS" | docker login -u "$LOGIN_USER" --password-stdin
    else
        echo "$LOGIN_PASS" | docker login "$REGISTRY" -u "$LOGIN_USER" --password-stdin
    fi
    echo "✓ Login successful!"
elif [ "$AUTH_CHOICE" != "1" ]; then
    echo "Invalid choice. Assuming you are already logged in."
fi

echo ""
echo "=========================================="
echo "Starting Build & Push Process"
echo "Target Image Prefix: $IMAGE_PREFIX"
echo "Image Tag: $TAG"
echo "=========================================="
echo ""

# --- 1. Build & Push Backend ---
echo ">>> [1/2] Processing: wineapp-backend..."
BACKEND_IMAGE="$IMAGE_PREFIX/wineapp-backend:$TAG"

echo "Building $BACKEND_IMAGE ..."
docker build --no-cache -t "$BACKEND_IMAGE" ./wineapp-backend

echo "Pushing $BACKEND_IMAGE ..."
docker push "$BACKEND_IMAGE"
echo "✓ Backend completed!"
echo ""

# --- 2. Build & Push Frontend ---
echo ">>> [2/2] Processing: wineapp-frontend..."
FRONTEND_IMAGE="$IMAGE_PREFIX/wineapp-frontend:$TAG"

echo "Building $FRONTEND_IMAGE ..."
docker build --no-cache -t "$FRONTEND_IMAGE" ./wineapp-frontend

echo "Pushing $FRONTEND_IMAGE ..."
docker push "$FRONTEND_IMAGE"
echo "✓ Frontend completed!"
echo ""

echo "=========================================="
echo "🎉 All tasks completed successfully!"
echo "Images are now available at: $IMAGE_PREFIX"
echo "=========================================="
