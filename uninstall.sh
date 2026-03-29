#!/bin/bash

# OpenClaw Docker Uninstallation Script
# This script removes OpenClaw Docker containers, images, volumes, and data

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="ghcr.io/openclaw/openclaw"
CONTAINER_NAME="openclaw"
VOLUME_NAME="openclaw_data"
NETWORK_NAME="openclaw_network"

echo -e "${RED}========================================${NC}"
echo -e "${RED}OpenClaw Docker Uninstallation Script${NC}"
echo -e "${RED}========================================${NC}"
echo -e "${YELLOW}WARNING: This will remove all OpenClaw data!${NC}"
echo -e "${YELLOW}This includes configurations, skills, and all stored data.${NC}"
echo -e "\n"

read -p "Are you sure you want to continue? (yes/no): " -r confirmation
if [[ ! $confirmation =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${GREEN}Uninstallation cancelled.${NC}"
    exit 0
fi

echo -e "\n${YELLOW}[1/6] Stopping container...${NC}"
if docker ps -a | grep -q $CONTAINER_NAME; then
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
    echo -e "${GREEN}✓ Container stopped and removed${NC}"
else
    echo -e "${YELLOW}⚠ Container not found${NC}"
fi

echo -e "\n${YELLOW}[2/6] Removing docker-compose resources...${NC}"
if [ -f docker-compose.yml ]; then
    docker-compose down -v 2>/dev/null || true
    rm -f docker-compose.yml
    echo -e "${GREEN}✓ docker-compose resources removed${NC}"
else
    echo -e "${YELLOW}⚠ docker-compose.yml not found${NC}"
fi

echo -e "\n${YELLOW}[3/6] Removing Docker volume...${NC}"
if docker volume inspect $VOLUME_NAME &> /dev/null; then
    read -p "Remove data volume $VOLUME_NAME? (yes/no): " -r remove_volume
    if [[ $remove_volume =~ ^[Yy][Ee][Ss]$ ]]; then
        docker volume rm $VOLUME_NAME
        echo -e "${GREEN}✓ Volume removed${NC}"
    else
        echo -e "${YELLOW}⚠ Volume preserved${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Volume not found${NC}"
fi

echo -e "\n${YELLOW}[4/6] Removing Docker network...${NC}"
if docker network inspect $NETWORK_NAME &> /dev/null; then
    docker network rm $NETWORK_NAME 2>/dev/null || true
    echo -e "${GREEN}✓ Network removed${NC}"
else
    echo -e "${YELLOW}⚠ Network not found${NC}"
fi

echo -e "\n${YELLOW}[5/6] Removing Docker image...${NC}"
read -p "Remove Docker image $IMAGE_NAME? (yes/no): " -r remove_image
if [[ $remove_image =~ ^[Yy][Ee][Ss]$ ]]; then
    docker rmi $IMAGE_NAME:$IMAGE_TAG 2>/dev/null || true
    echo -e "${GREEN}✓ Image removed${NC}"
else
    echo -e "${YELLOW}⚠ Image preserved${NC}"
fi

echo -e "\n${YELLOW}[6/6] Cleaning up configuration files...${NC}"
read -p "Remove .env and configuration files? (yes/no): " -r remove_config
if [[ $remove_config =~ ^[Yy][Ee][Ss]$ ]]; then
    rm -f .env .env.template docker-compose.yml
    echo -e "${GREEN}✓ Configuration files removed${NC}"
else
    echo -e "${YELLOW}⚠ Configuration files preserved${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Uninstallation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

# Optional: Check for orphaned resources
echo -e "\n${YELLOW}Checking for orphaned resources...${NC}"
ORPHANED=$(docker ps -a --filter "name=openclaw" --format "{{.Names}}" | wc -l)
if [ $ORPHANED -gt 0 ]; then
    echo -e "${YELLOW}⚠ Found $ORPHANED orphaned containers. Run 'docker rm -f \$(docker ps -a -q --filter name=openclaw)' to remove them.${NC}"
fi

echo -e "\n${BLUE}Thank you for trying OpenClaw!${NC}"