#!/bin/bash

# --- REQUIRED ENV VARIABLES ---
# GITEA_REGISTRY       => ex: gitea.example.com:5000
# IMAGE_TAG            => Optional (default: latest)
# SLEEP_INTERVAL       => Optional (default: 60 seconds)
# ------------------------------

# Config
REGISTRY_URL="${GITEA_REGISTRY:-gitea.example.com:5000}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
SLEEP_INTERVAL="${SLEEP_INTERVAL:-60}"

# Ensure required env vars
if [ -z "$GITEA_REGISTRY" ]; then
  echo "❌ Error: Environment variable 'GITEA_REGISTRY' is not set."
  exit 1
fi

# Ensure dependencies
for cmd in jq curl docker; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Error: $cmd not installed"
    exit 1
  fi
done

# Get image list from registry
get_image_list() {
  echo curl -s "https://${REGISTRY_URL}/v2/_catalog" 
  curl -s "https://${REGISTRY_URL}/v2/_catalog" | jq -r '.repositories[]'
}

# Get digest of an image from registry
get_registry_digest() {
  local image="$1"
  curl -s -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
       "https://${REGISTRY_URL}/v2/${image}/manifests/${IMAGE_TAG}" | \
       jq -r '.config.digest'
}

# Get current container digest
get_running_digest() {
  local container_name="$1"
  if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
    docker inspect --format='{{.Image}}' "$container_name"
  else
    echo "NO_CONTAINER_RUNNING"
  fi
}

# Deploy or update a single image
process_image() {
  local image="$1"
  local container_name="${image//\//_}"
  local image_ref="${REGISTRY_URL}/${image}:${IMAGE_TAG}"

  echo "🔍 Processing $image_ref..."

  local running_digest
  local registry_digest

  running_digest=$(get_running_digest "$container_name")
  registry_digest=$(get_registry_digest "$image")

  if [ -z "$registry_digest" ]; then
    echo "⚠️  Could not get digest for $image_ref"
    return
  fi

  if [ "$running_digest" == "NO_CONTAINER_RUNNING" ]; then
    echo "🚀 No container found. Deploying $container_name..."
    docker pull "$image_ref"
    docker run -d --name "$container_name" "$image_ref"
  elif [ "$running_digest" != "$registry_digest" ]; then
    echo "🔄 Update detected for $image_ref"
    docker pull "$image_ref"
    docker stop "$container_name"
    docker rm "$container_name"
    docker run -d --name "$container_name" "$image_ref"
  else
    echo "✅ $container_name is up to date."
  fi
}

# Main loop
echo "🚀 Starting global auto-deploy loop..."
while true; do
  images=$(get_image_list)
  for img in $images; do
    process_image "$img"
  done
  echo "🕒 Sleeping for $SLEEP_INTERVAL seconds..."
  sleep "$SLEEP_INTERVAL"
done
