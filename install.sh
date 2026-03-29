#!/bin/bash

# OpenClaw Complete Installation Script for Fedora/CentOS/RHEL
# This script installs Docker, sets up services, and deploys OpenClaw

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
INSTALL_DIR="$HOME/openclaw"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        print_error "Cannot detect OS"
        exit 1
    fi
}

# Function to install Docker on Fedora
install_docker_fedora() {
    print_status "Installing Docker on Fedora..."
    
    # Remove old versions
    sudo dnf remove -y docker docker-client docker-client-latest docker-common \
        docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
    
    # Install dependencies
    sudo dnf install -y dnf-plugins-core
    
    # Add Docker repository
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    
    # Install Docker
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    print_success "Docker installed successfully"
}

# Function to install Docker on CentOS/RHEL
install_docker_centos() {
    print_status "Installing Docker on CentOS/RHEL..."
    
    # Remove old versions
    sudo yum remove -y docker docker-client docker-client-latest docker-common \
        docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
    
    # Install dependencies
    sudo yum install -y yum-utils
    
    # Add Docker repository
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Install Docker
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    print_success "Docker installed successfully"
}

# Function to install Docker on Ubuntu/Debian
install_docker_ubuntu() {
    print_status "Installing Docker on Ubuntu/Debian..."
    
    # Update packages
    sudo apt-get update
    
    # Install dependencies
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    
    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    print_success "Docker installed successfully"
}

# Function to check and install Docker if not present
check_and_install_docker() {
    print_status "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        print_warning "Docker not found. Installing Docker..."
        
        detect_os
        
        case $OS in
            fedora)
                install_docker_fedora
                ;;
            centos|rhel|rocky|almalinux)
                install_docker_centos
                ;;
            ubuntu|debian)
                install_docker_ubuntu
                ;;
            *)
                print_error "Unsupported OS: $OS"
                print_error "Please install Docker manually from https://docs.docker.com/engine/install/"
                exit 1
                ;;
        esac
        
        print_warning "Please log out and back in (or run 'newgrp docker') for group changes to take effect"
        print_warning "After logging back in, re-run this script"
        exit 0
    else
        print_success "Docker is already installed"
    fi
}

# Function to check Docker Compose
check_docker_compose() {
    print_status "Checking Docker Compose..."
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed"
        print_status "Installing Docker Compose Plugin..."
        
        case $OS in
            fedora|centos|rhel)
                sudo dnf install -y docker-compose-plugin
                ;;
            ubuntu|debian)
                sudo apt-get install -y docker-compose-plugin
                ;;
        esac
    fi
    
    print_success "Docker Compose is available"
}

# Function to check Ollama (optional)
check_ollama() {
    print_status "Checking Ollama (optional)..."
    
    if curl -s http://localhost:11434/api/tags &> /dev/null; then
        print_success "✓ Ollama is running on host"
        OLLAMA_HOST="host.docker.internal"
    else
        print_warning "⚠ Ollama is not running or not detected"
        print_warning "  You can still use other LLM providers"
        OLLAMA_HOST="host.docker.internal"
    fi
}

# Function to create installation directory
create_install_dir() {
    print_status "Creating installation directory..."
    
    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
        print_success "Created directory: $INSTALL_DIR"
    else
        print_warning "Directory already exists: $INSTALL_DIR"
    fi
    
    cd "$INSTALL_DIR"
}

# Function to create Docker volume
create_volume() {
    print_status "Creating Docker volume..."
    
    if docker volume inspect $VOLUME_NAME &> /dev/null; then
        print_warning "Volume $VOLUME_NAME already exists"
    else
        docker volume create $VOLUME_NAME
        print_success "Created volume: $VOLUME_NAME"
    fi
}

# Function to create Docker network
create_network() {
    print_status "Creating Docker network..."
    
    if docker network inspect $NETWORK_NAME &> /dev/null; then
        print_warning "Network $NETWORK_NAME already exists"
    else
        docker network create $NETWORK_NAME
        print_success "Created network: $NETWORK_NAME"
    fi
}

# Function to create docker-compose.yml
create_docker_compose() {
    print_status "Creating docker-compose.yml..."
    
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
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - NODE_ENV=production
      - OLLAMA_HOST=http://\${OLLAMA_HOST:-${OLLAMA_HOST}}:11434
      - TELEGRAM_BOT_TOKEN=\${TELEGRAM_BOT_TOKEN:-}
      - OPENAI_API_KEY=\${OPENAI_API_KEY:-}
      - ANTHROPIC_API_KEY=\${ANTHROPIC_API_KEY:-}
      - GOOGLE_API_KEY=\${GOOGLE_API_KEY:-}
      - ELEVENLABS_API_KEY=\${ELEVENLABS_API_KEY:-}
      - BRAVE_SEARCH_API_KEY=\${BRAVE_SEARCH_API_KEY:-}
      - TAVILY_API_KEY=\${TAVILY_API_KEY:-}
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
    
    print_success "Created docker-compose.yml"
}

# Function to create .env template
create_env_template() {
    print_status "Creating .env template..."
    
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
ELEVENLABS_API_KEY=
BRAVE_SEARCH_API_KEY=
TAVILY_API_KEY=

# Ollama host (if running locally)
OLLAMA_HOST=${OLLAMA_HOST}
EOF
        
        print_success "Created .env.template"
        print_warning "Copy .env.template to .env and add your API keys:"
        echo "  cp .env.template .env"
        echo "  nano .env"
    else
        print_warning ".env file already exists"
    fi
}

# Function to pull Docker image
pull_image() {
    print_status "Pulling Docker image..."
    
    docker pull ${IMAGE_NAME}:${IMAGE_TAG}
    print_success "Image pulled successfully"
}

# Function to start container
start_container() {
    print_status "Starting OpenClaw container..."
    
    docker-compose up -d
    
    sleep 5
    
    if docker ps | grep -q $CONTAINER_NAME; then
        print_success "OpenClaw is running!"
        return 0
    else
        print_error "Failed to start container"
        docker-compose logs
        return 1
    fi
}

# Function to create systemd service (optional)
create_systemd_service() {
    print_status "Creating systemd service for OpenClaw..."
    
    sudo tee /etc/systemd/system/openclaw.service > /dev/null <<EOF
[Unit]
Description=OpenClaw Container
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
ExecReload=/usr/bin/docker-compose restart
User=${USER}
Group=${USER}

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable openclaw.service
    
    print_success "Created systemd service: openclaw.service"
    print_status "Manage with: sudo systemctl {start|stop|restart|status} openclaw"
}

# Function to configure firewall
configure_firewall() {
    print_status "Configuring firewall..."
    
    if command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-port=3000/tcp 2>/dev/null || true
        sudo firewall-cmd --permanent --add-port=8080/tcp 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
        print_success "Firewall configured (ports 3000, 8080)"
    else
        print_warning "firewalld not found, skipping firewall configuration"
    fi
}

# Function to show completion message
show_completion() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Installation Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "Container: ${GREEN}${CONTAINER_NAME}${NC}"
    echo -e "Web UI:    ${GREEN}http://localhost:3000${NC}"
    echo -e "API:       ${GREEN}http://localhost:8080${NC}"
    echo -e "Data Dir:  ${GREEN}${INSTALL_DIR}${NC}"
    echo ""
    echo -e "${YELLOW}Useful commands:${NC}"
    echo -e "  View logs:    ${BLUE}cd ${INSTALL_DIR} && docker-compose logs -f${NC}"
    echo -e "  Stop:         ${BLUE}cd ${INSTALL_DIR} && docker-compose stop${NC}"
    echo -e "  Start:        ${BLUE}cd ${INSTALL_DIR} && docker-compose start${NC}"
    echo -e "  Restart:      ${BLUE}cd ${INSTALL_DIR} && docker-compose restart${NC}"
    echo -e "  Shell:        ${BLUE}docker exec -it ${CONTAINER_NAME} /bin/sh${NC}"
    echo -e "  Service:      ${BLUE}sudo systemctl {start|stop|restart|status} openclaw${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "  1. Add your API keys:"
    echo -e "     ${BLUE}cd ${INSTALL_DIR} && cp .env.template .env && nano .env${NC}"
    echo -e "  2. Restart with new keys:"
    echo -e "     ${BLUE}cd ${INSTALL_DIR} && docker-compose down && docker-compose up -d${NC}"
    echo -e "  3. Configure OpenClaw via Web UI: ${GREEN}http://localhost:3000${NC}"
    echo ""
}

# Function to uninstall (if needed)
uninstall() {
    print_warning "This will remove OpenClaw and all data!"
    read -p "Are you sure? (yes/no): " -r confirmation
    
    if [[ $confirmation =~ ^[Yy][Ee][Ss]$ ]]; then
        cd "$INSTALL_DIR" 2>/dev/null || true
        docker-compose down -v 2>/dev/null || true
        docker volume rm $VOLUME_NAME 2>/dev/null || true
        docker network rm $NETWORK_NAME 2>/dev/null || true
        docker rmi ${IMAGE_NAME}:${IMAGE_TAG} 2>/dev/null || true
        sudo systemctl disable openclaw.service 2>/dev/null || true
        sudo rm -f /etc/systemd/system/openclaw.service
        rm -rf "$INSTALL_DIR"
        print_success "OpenClaw uninstalled successfully"
        exit 0
    else
        print_status "Uninstallation cancelled"
        exit 0
    fi
}

# Main execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}OpenClaw Complete Installation Script${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Check for uninstall flag
    if [ "$1" = "--uninstall" ] || [ "$1" = "-u" ]; then
        uninstall
        exit 0
    fi
    
    # Run installation steps
    check_and_install_docker
    check_docker_compose
    create_install_dir
    check_ollama
    create_volume
    create_network
    create_docker_compose
    create_env_template
    pull_image
    start_container
    configure_firewall
    create_systemd_service
    show_completion
}

# Run main function with all arguments
main "$@"
