#!/bin/bash

# Check if container exists (running or stopped) and handle it
if docker ps -a --filter name="open-webui$" --format "{{.Names}}" | grep -q "open-webui$"; then
    echo "Found existing open-webui container. Stopping and removing..."

    # Stop the container if it's running
    docker stop open-webui 2>/dev/null || echo "Container was not running"

    # Remove the container
    docker rm open-webui 2>/dev/null || echo "Failed to remove container"

    echo "Container stopped and removed"
else
    echo "No existing open-webui container found"
fi

# Start the new container
echo "Starting new open-webui container..."
docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway \
          -v open-webui:/app/backend/data \
          -v ollama-models:/root/.ollama \
          -e OLLAMA_KEEP_ALIVE=2m \
          -e OLLAMA_NUM_PARALLEL=1 \
          -e OLLAMA_MAX_LOADED_MODELS=1 \
          --name open-webui --restart always \
          ghcr.io/open-webui/open-webui:ollama

if [ $? -eq 0 ]; then
    echo "Container started successfully"
else
    echo "Failed to start container"
    exit 1
fi