#!/bin/bash

# Peepl 2025 Setup Script
# This script sets up the complete Peepl 2025 environment

set -e

echo "🚀 Setting up Peepl 2025..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Node.js is installed
check_node() {
    print_status "Checking Node.js installation..."
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        print_success "Node.js is installed: $NODE_VERSION"
        
        # Check if version is >= 16
        NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1 | sed 's/v//')
        if [ "$NODE_MAJOR" -lt 16 ]; then
            print_error "Node.js version 16 or higher is required. Current version: $NODE_VERSION"
            exit 1
        fi
    else
        print_error "Node.js is not installed. Please install Node.js 16 or higher."
        exit 1
    fi
}

# Check if npm is installed
check_npm() {
    print_status "Checking npm installation..."
    if command -v npm &> /dev/null; then
        NPM_VERSION=$(npm --version)
        print_success "npm is installed: $NPM_VERSION"
    else
        print_error "npm is not installed. Please install npm."
        exit 1
    fi
}

# Install backend dependencies
install_backend_deps() {
    print_status "Installing backend dependencies..."
    cd "$(dirname "$0")/.."
    
    if [ ! -f "package.json" ]; then
        print_error "package.json not found. Are you in the correct directory?"
        exit 1
    fi
    
    npm install
    print_success "Backend dependencies installed successfully"
}

# Setup environment file
setup_env() {
    print_status "Setting up environment configuration..."
    
    if [ ! -f ".env" ]; then
        if [ -f "env.example" ]; then
            cp env.example .env
            print_success "Created .env file from env.example"
            print_warning "Please update .env file with your actual configuration values"
        else
            print_error "env.example file not found"
            exit 1
        fi
    else
        print_warning ".env file already exists. Skipping creation."
    fi
}

# Setup mobile app
setup_mobile_app() {
    print_status "Setting up mobile app..."
    
    if [ -d "PeeplMobile" ]; then
        cd PeeplMobile
        
        if [ -f "package.json" ]; then
            print_status "Installing mobile app dependencies..."
            npm install
            print_success "Mobile app dependencies installed successfully"
            
            # Check if React Native CLI is installed
            if command -v react-native &> /dev/null; then
                print_success "React Native CLI is available"
            else
                print_warning "React Native CLI not found. Install with: npm install -g react-native-cli"
            fi
            
            # Setup iOS pods if on macOS
            if [[ "$OSTYPE" == "darwin"* ]]; then
                if [ -d "ios" ]; then
                    print_status "Installing iOS pods..."
                    cd ios && pod install && cd ..
                    print_success "iOS pods installed successfully"
                fi
            else
                print_warning "iOS setup skipped (not on macOS)"
            fi
        else
            print_error "Mobile app package.json not found"
        fi
        
        cd ..
    else
        print_warning "PeeplMobile directory not found. Skipping mobile app setup."
    fi
}

# Create necessary directories
create_directories() {
    print_status "Creating necessary directories..."
    
    mkdir -p logs
    mkdir -p uploads
    mkdir -p backups
    mkdir -p nginx/ssl
    
    print_success "Directories created successfully"
}

# Setup database
setup_database() {
    print_status "Setting up database..."
    
    if [ -f "scripts/init-database.js" ]; then
        print_status "Running database initialization..."
        node scripts/init-database.js
        print_success "Database initialized successfully"
    else
        print_warning "Database initialization script not found. Skipping database setup."
    fi
}

# Check Docker installation
check_docker() {
    print_status "Checking Docker installation..."
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        print_success "Docker is installed: $DOCKER_VERSION"
        
        if command -v docker-compose &> /dev/null; then
            COMPOSE_VERSION=$(docker-compose --version)
            print_success "Docker Compose is installed: $COMPOSE_VERSION"
        else
            print_warning "Docker Compose not found. Install Docker Compose for containerized deployment."
        fi
    else
        print_warning "Docker not found. Install Docker for containerized deployment."
    fi
}

# Main setup function
main() {
    echo "🎯 Starting Peepl 2025 setup..."
    echo "=================================="
    
    check_node
    check_npm
    install_backend_deps
    setup_env
    create_directories
    setup_mobile_app
    setup_database
    check_docker
    
    echo "=================================="
    print_success "Peepl 2025 setup completed successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Update .env file with your actual configuration values"
    echo "2. Set up Firebase project and get API keys"
    echo "3. Configure Google Maps API key"
    echo "4. Run 'npm start' to start the backend server"
    echo "5. Run 'cd PeeplMobile && npm run ios' (or android) to start mobile app"
    echo ""
    echo "📚 For detailed setup instructions, see README.md"
    echo "🐛 For troubleshooting, check the documentation"
}

# Run main function
main "$@"
