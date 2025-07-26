#!/bin/bash

NETWORK_NAME="traefik_network"

if ! docker network ls | grep -q "$NETWORK_NAME"; then
  echo "Network '$NETWORK_NAME' not found. Creating it now..."
  docker network create "$NETWORK_NAME"
else
  echo "Network '$NETWORK_NAME' already exists."
fi

# Load environment variables from all .env files
for env_file in $(find . -mindepth 2 -name '.env'); do
  echo "Loading environment variables from $env_file"
  set -a
  source "$env_file"
  set +a
done

# Build Docker Compose command
COMPOSE_FILES=""
for f in $(find . -mindepth 2 -name 'docker-compose.yml'); do
  COMPOSE_FILES+=" -f $f"
done

COMMAND="docker compose$COMPOSE_FILES $@"

echo "Running command: $COMMAND"
eval $COMMAND
