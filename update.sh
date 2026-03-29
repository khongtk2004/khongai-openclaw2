#!/bin/bash

# Update script for OpenClaw

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Updating OpenClaw...${NC}"

# Pull latest image
docker pull ghcr.io/openclaw/openclaw:latest

# Recreate container
docker-compose down
docker-compose up -d

echo -e "${GREEN}Update complete!${NC}"
docker-compose ps