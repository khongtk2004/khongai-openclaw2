#!/bin/bash

# OpenClaw Docker Installation Script
# This script installs and runs OpenClaw using Docker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="ghcr.io/openclaw/openclaw"
IMAGE_TAG="latest"
CONTAINER_NAME="openclaw"
VOLUME_NAME="openclaw_data"
NETWORK_NAME="openclaw_network"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}OpenClaw Docker Installation Script${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if Docker is installed
echo -e "\n${YELLOW}[1/6] Checking Docker installation...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
    echo -e "Visit: https://docs.docker.com/engine/install/"
    exit 1
fi
echo -e "${GREEN}✓ Docker is installed${NC}"

# Check if Docker Compose is installed
echo -e "\n${YELLOW}[2/6] Checking Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose is available${NC}"

# Check if Ollama is running (optional)
echo -e "\n${YELLOW}[3/6] Checking Ollama (optional)...${NC}"
if curl -s http://localhost:11434/api/tags &> /dev/null; then
    echo -e "${GREEN}✓ Ollama is running on host${NC}"
    OLLAMA_HOST="host.docker.internal"
else
    echo -e "${YELLOW}⚠ Ollama is not running or not detected${NC}"
    echo -e "  You can still use other LLM providers"
    OLLAMA_HOST="host.docker.internal"
fi

# Create Docker volume for persistent data
echo -e "\n${YELLOW}[4/6] Creating Docker volume...${NC}"
if docker volume inspect $VOLUME_NAME &> /dev/null; then
    echo -e "${YELLOW}⚠ Volume $VOLUME_NAME already exists${NC}"
else
    docker volume create $VOLUME_NAME
    echo -e "${GREEN}✓ Created volume: $VOLUME_NAME${NC}"
fi

# Create Docker network
echo -e "\n${YELLOW}[5/6] Creating Docker network...${NC}"
if docker network inspect $NETWORK_NAME &> /dev/null; then
    echo -e "${YELLOW}⚠ Network $NETWORK_NAME already exists${NC}"
else
    docker network create $NETWORK_NAME
    echo -e "${GREEN}✓ Created network: $NETWORK_NAME${NC}"
fi

# Create docker-compose.yml
echo -e "\n${YELLOW}[6/6] Creating docker-compose.yml...${NC}"

cat > docker-compose.yml <<EOF
version: '3.8'

services:
  openclaw:
    image: ${IMAGE_NAME}:${IMAGE_TAG}
    container_name: ${CONTAINER_NAME}
    restart: unless-stopped
    ports:
      - "3000:3000"  # Web UI port
      - "8080:8080"  # API port
    volumes:
      - ${VOLUME_NAME}:/app/data
      - /var/run/docker.sock:/var/run/docker.sock  # Optional: for Docker skills
    environment:
      - NODE_ENV=production
      - OLLAMA_HOST=http://${OLLAMA_HOST}:11434
      # Add your API keys here or use .env file
      - TELEGRAM_BOT_TOKEN=\${TELEGRAM_BOT_TOKEN:-}
      - OPENAI_API_KEY=\${OPENAI_API_KEY:-}
      - ANTHROPIC_API_KEY=\${ANTHROPIC_API_KEY:-}
      - GOOGLE_API_KEY=\${GOOGLE_API_KEY:-}
    networks:
      - ${NETWORK_NAME}
    # Uncomment for host network (to access host Ollama easily)
    # network_mode: host

networks:
  ${NETWORK_NAME}:
    external: true

volumes:
  ${VOLUME_NAME}:
    external: true
EOF

echo -e "${GREEN}✓ Created docker-compose.yml${NC}"

# Create .env template
if [ ! -f .env ]; then
    cat > .env.template <<EOF
# OpenClaw Environment Variables
# Copy this to .env and fill in your values

# Telegram Bot Token (required for Telegram channel)
TELEGRAM_BOT_TOKEN=

# OpenAI API Key (for OpenAI models)
OPENAI_API_KEY=

# Anthropic API Key (for Claude models)
ANTHROPIC_API_KEY=

# Google API Key (for Gemini models and Google services)
GOOGLE_API_KEY=

# Other optional API keys
# ELEVENLABS_API_KEY=
# BRAVE_SEARCH_API_KEY=
# TAVILY_API_KEY=
EOF
    echo -e "${GREEN}✓ Created .env.template (copy to .env and add your keys)${NC}"
fi

# Pull the latest image
echo -e "\n${YELLOW}Pulling Docker image...${NC}"
docker pull ${IMAGE_NAME}:${IMAGE_TAG}
echo -e "${GREEN}✓ Image pulled successfully${NC}"

# Start the container
echo -e "\n${YELLOW}Starting OpenClaw container...${NC}"
docker-compose up -d

# Check if container is running
sleep 5
if docker ps | grep -q $CONTAINER_NAME; then
    echo -e "${GREEN}✓ OpenClaw is running!${NC}"
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${GREEN}Installation Complete!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Container: ${GREEN}$CONTAINER_NAME${NC}"
    echo -e "Web UI:    ${GREEN}http://localhost:3000${NC}"
    echo -e "API:       ${GREEN}http://localhost:8080${NC}"
    echo -e "\n${YELLOW}Useful commands:${NC}"
    echo -e "  View logs:    ${BLUE}docker-compose logs -f${NC}"
    echo -e "  Stop:         ${BLUE}docker-compose stop${NC}"
    echo -e "  Start:        ${BLUE}docker-compose start${NC}"
    echo -e "  Restart:      ${BLUE}docker-compose restart${NC}"
    echo -e "  Shell:        ${BLUE}docker exec -it $CONTAINER_NAME /bin/sh${NC}"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo -e "  1. Copy .env.template to .env and add your API keys"
    echo -e "  2. Run ${BLUE}docker-compose down && docker-compose up -d${NC} to apply changes"
    echo -e "  3. Configure OpenClaw via Web UI at ${GREEN}http://localhost:3000${NC}"
else
    echo -e "${RED}Failed to start container. Check logs with: docker-compose logs${NC}"
    exit 1
fi
