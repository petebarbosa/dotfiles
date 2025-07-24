#!/bin/bash

NETWORK_NAME="traefik_network"

if ! docker network ls | grep -q "$NETWORK_NAME"; then
  echo "Network '$NETWORK_NAME' not found. Creating it now..."
  docker network create "$NETWORK_NAME"
else
  echo "Network '$NETWORK_NAME' already exists."
fi

for env_file in $(find . -mindepth 2 -name '.env'); do
  echo "Loading environment variables from $env_file"
  export $(grep -v '^#' "$env_file" | xargs)
done

COMMAND="docker compose"
for f in $(find . -mindepth 2 -name 'docker-compose.yml'); do
  COMMAND+=" -f $f"
done

COMMAND+=" $@"

echo "Running command: $COMMAND"
eval $COMMAND
