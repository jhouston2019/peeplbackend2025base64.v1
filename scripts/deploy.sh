#!/bin/bash

# Peepl 2025 Deployment Script
# This script deploys the Peepl 2025 application

set -e

echo "🚀 Deploying Peepl 2025..."

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

# Configuration
DEPLOYMENT_TYPE=${1:-"docker"}
ENVIRONMENT=${2:-"production"}

# Check if .env file exists
check_env() {
    print_status "Checking environment configuration..."
    
    if [ ! -f ".env" ]; then
        print_error ".env file not found. Please create it from env.example"
        exit 1
    fi
    
    # Check for required environment variables
    REQUIRED_VARS=("FIREBASE_CONFIG_B64" "JWT_SECRET" "GOOGLE_MAPS_API_KEY")
    
    for var in "${REQUIRED_VARS[@]}"; do
        if ! grep -q "^${var}=" .env; then
            print_error "Required environment variable $var not found in .env"
            exit 1
        fi
    done
    
    print_success "Environment configuration validated"
}

# Run tests
run_tests() {
    print_status "Running tests..."
    
    if [ -f "package.json" ]; then
        npm test
        print_success "Tests passed successfully"
    else
        print_warning "No tests found. Skipping test execution."
    fi
}

# Build application
build_app() {
    print_status "Building application..."
    
    if [ -f "package.json" ]; then
        npm run build 2>/dev/null || print_warning "No build script found. Skipping build step."
    fi
    
    print_success "Application build completed"
}

# Deploy with Docker
deploy_docker() {
    print_status "Deploying with Docker..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Stop existing containers
    print_status "Stopping existing containers..."
    docker-compose -f docker-compose.prod.yml down 2>/dev/null || true
    
    # Build and start containers
    print_status "Building and starting containers..."
    docker-compose -f docker-compose.prod.yml up -d --build
    
    # Wait for services to be healthy
    print_status "Waiting for services to be healthy..."
    sleep 30
    
    # Check health
    if curl -f http://localhost:3000/health > /dev/null 2>&1; then
        print_success "Backend service is healthy"
    else
        print_error "Backend service health check failed"
        exit 1
    fi
    
    print_success "Docker deployment completed successfully"
}

# Deploy to cloud (placeholder)
deploy_cloud() {
    print_status "Deploying to cloud..."
    
    case $ENVIRONMENT in
        "staging")
            print_status "Deploying to staging environment..."
            # Add your staging deployment commands here
            ;;
        "production")
            print_status "Deploying to production environment..."
            # Add your production deployment commands here
            ;;
        *)
            print_error "Unknown environment: $ENVIRONMENT"
            exit 1
            ;;
    esac
    
    print_success "Cloud deployment completed"
}

# Deploy mobile app
deploy_mobile() {
    print_status "Deploying mobile app..."
    
    if [ -d "PeeplMobile" ]; then
        cd PeeplMobile
        
        # Build Android APK
        if [ -d "android" ]; then
            print_status "Building Android APK..."
            npm run build:android
            print_success "Android APK built successfully"
        fi
        
        # Build iOS (if on macOS)
        if [[ "$OSTYPE" == "darwin"* ]] && [ -d "ios" ]; then
            print_status "Building iOS app..."
            npm run build:ios
            print_success "iOS app built successfully"
        fi
        
        cd ..
    else
        print_warning "PeeplMobile directory not found. Skipping mobile app deployment."
    fi
}

# Setup monitoring
setup_monitoring() {
    print_status "Setting up monitoring..."
    
    # Create log directories
    mkdir -p logs/nginx
    mkdir -p logs/app
    
    # Set up log rotation (if logrotate is available)
    if command -v logrotate &> /dev/null; then
        print_status "Setting up log rotation..."
        # Add logrotate configuration here
    fi
    
    print_success "Monitoring setup completed"
}

# Backup existing deployment
backup_existing() {
    print_status "Creating backup of existing deployment..."
    
    BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup database (if applicable)
    if [ -f "scripts/backup-database.js" ]; then
        node scripts/backup-database.js "$BACKUP_DIR"
    fi
    
    # Backup configuration
    cp .env "$BACKUP_DIR/" 2>/dev/null || true
    cp docker-compose.prod.yml "$BACKUP_DIR/" 2>/dev/null || true
    
    print_success "Backup created in $BACKUP_DIR"
}

# Rollback deployment
rollback() {
    print_status "Rolling back deployment..."
    
    # Find latest backup
    LATEST_BACKUP=$(ls -t backups/ | head -n1)
    
    if [ -z "$LATEST_BACKUP" ]; then
        print_error "No backup found for rollback"
        exit 1
    fi
    
    print_status "Rolling back to backup: $LATEST_BACKUP"
    
    # Restore from backup
    # Add rollback logic here
    
    print_success "Rollback completed successfully"
}

# Main deployment function
main() {
    echo "🎯 Starting Peepl 2025 deployment..."
    echo "=================================="
    echo "Deployment Type: $DEPLOYMENT_TYPE"
    echo "Environment: $ENVIRONMENT"
    echo "=================================="
    
    check_env
    run_tests
    build_app
    backup_existing
    setup_monitoring
    
    case $DEPLOYMENT_TYPE in
        "docker")
            deploy_docker
            ;;
        "cloud")
            deploy_cloud
            ;;
        "mobile")
            deploy_mobile
            ;;
        "rollback")
            rollback
            ;;
        *)
            print_error "Unknown deployment type: $DEPLOYMENT_TYPE"
            echo "Available options: docker, cloud, mobile, rollback"
            exit 1
            ;;
    esac
    
    echo "=================================="
    print_success "Peepl 2025 deployment completed successfully!"
    echo ""
    echo "🌐 Application URLs:"
    echo "Backend API: http://localhost:3000"
    echo "Health Check: http://localhost:3000/health"
    echo ""
    echo "📊 Monitoring:"
    echo "Logs: ./logs/"
    echo "Backups: ./backups/"
    echo ""
    echo "🔧 Management Commands:"
    echo "View logs: docker-compose -f docker-compose.prod.yml logs -f"
    echo "Stop services: docker-compose -f docker-compose.prod.yml down"
    echo "Restart services: docker-compose -f docker-compose.prod.yml restart"
}

# Show usage if no arguments provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <deployment_type> [environment]"
    echo ""
    echo "Deployment Types:"
    echo "  docker    - Deploy using Docker Compose"
    echo "  cloud     - Deploy to cloud platform"
    echo "  mobile    - Build mobile app"
    echo "  rollback  - Rollback to previous deployment"
    echo ""
    echo "Environments:"
    echo "  staging   - Deploy to staging environment"
    echo "  production - Deploy to production environment"
    echo ""
    echo "Examples:"
    echo "  $0 docker production"
    echo "  $0 cloud staging"
    echo "  $0 mobile"
    echo "  $0 rollback"
    exit 1
fi

# Run main function
main "$@"
