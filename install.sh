#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${2}${1}${NC}"
}

# Function to generate a secure random key
generate_secure_key() {
    local length=$1
    tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c $length
}

# Check if running in an empty directory
check_directory() {
    if [ -n "$(ls -A | grep -v '^\.' | grep -v '^install\.sh$')" ]; then
        print_message "Error: Directory is not empty. Please use an empty directory." "$RED"
        exit 1
    fi
}

# Clone the repository
clone_repository() {
    print_message "=== Cloning Repository ===" "$YELLOW"
    mkdir -p rentickets
    if git clone https://github.com/DankiCalamari/rentickets ./rentickets; then
        print_message "✓ Repository cloned successfully" "$GREEN"
        cd rentickets
    else
        print_message "Error cloning repository" "$RED"
        exit 1
    fi
}

# Gather configuration
get_config() {
    print_message "\n=== Server Configuration ===" "$YELLOW"
    
    # Database configuration
    read -p "Enter MySQL root username [root]: " DB_ROOT_USER
    DB_ROOT_USER=${DB_ROOT_USER:-root}
    
    read -s -p "Enter MySQL root password: " DB_ROOT_PASSWORD
    echo
    
    # Database connection details
    DB_HOST="localhost"
    DB_PORT=3306
    DB_NAME="tickets"
    APP_DB_USER="tickets"
    
    # Generate JWT secret
    JWT_SECRET=$(generate_secure_key 32)
    
    # Email configuration (optional)
    print_message "\n=== Email Configuration (Optional) ===" "$YELLOW"
    read -p "Enter SMTP email (leave empty to skip): " SMTP_USER
    if [ -n "$SMTP_USER" ]; then
        read -s -p "Enter SMTP password: " SMTP_PASSWORD
        echo
    fi
    SMTP_HOST="smtp.office365.com"
    SMTP_PORT=587
    
    # Azure configuration (optional)
    print_message "\n=== Azure AD Configuration (Optional) ===" "$YELLOW"
    read -p "Enter Azure Client ID (leave empty to skip): " AZURE_CLIENT_ID
    if [ -n "$AZURE_CLIENT_ID" ]; then
        read -s -p "Enter Azure Client Secret: " AZURE_CLIENT_SECRET
        echo
        read -p "Enter Azure Tenant ID: " AZURE_TENANT_ID
    fi
}

# Setup database
setup_database() {
    print_message "\n=== Setting up database ===" "$YELLOW"
    
    # Generate secure password for application database user
    APP_DB_PASSWORD=$(generate_secure_key 16)
    
    # Create database and user
    mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_ROOT_USER" -p"$DB_ROOT_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$APP_DB_USER'@'localhost' IDENTIFIED BY '$APP_DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$APP_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        print_message "✓ Database setup completed successfully" "$GREEN"
    else
        print_message "Error setting up database" "$RED"
        exit 1
    fi
}

# Create environment files
create_env_files() {
    print_message "\n=== Creating environment files ===" "$YELLOW"
    
    # Server .env
    cat > ./server/.env << EOF
# Server Configuration
PORT=3001

# Database Configuration
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$APP_DB_USER
DB_PASSWORD=$APP_DB_PASSWORD
DB_SSL=false

# JWT Configuration
JWT_SECRET=$JWT_SECRET

# Email Configuration
SMTP_HOST=$SMTP_HOST
SMTP_PORT=$SMTP_PORT
SMTP_USER=$SMTP_USER
SMTP_PASSWORD=$SMTP_PASSWORD

# Azure AD Configuration
AZURE_CLIENT_ID=$AZURE_CLIENT_ID
AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET
AZURE_TENANT_ID=$AZURE_TENANT_ID

# CORS Configuration
CORS_ORIGIN=http://localhost:5173
EOF
    
    # Client .env
    cat > ./client/.env << EOF
VITE_APP_API_URL=http://localhost:3001
VITE_APP_AZURE_CLIENT_ID=$AZURE_CLIENT_ID
VITE_APP_AZURE_TENANT_ID=$AZURE_TENANT_ID
VITE_APP_ENV=development
EOF
    
    print_message "✓ Environment files created successfully" "$GREEN"
}

# Install dependencies
install_dependencies() {
    print_message "\n=== Installing dependencies ===" "$YELLOW"
    
    print_message "📦 Installing server dependencies..." "$YELLOW"
    cd server && npm install
    if [ $? -ne 0 ]; then
        print_message "Error installing server dependencies" "$RED"
        exit 1
    fi
    cd ..
    
    print_message "📦 Installing client dependencies..." "$YELLOW"
    cd client && npm install
    if [ $? -ne 0 ]; then
        print_message "Error installing client dependencies" "$RED"
        exit 1
    fi
    cd ..
    
    print_message "✓ Dependencies installed successfully" "$GREEN"
}

# Main installation process
main() {
    print_message "=== Modern Ticketing System Installation ===" "$YELLOW"
    
    check_directory
    clone_repository
    get_config
    setup_database
    create_env_files
    install_dependencies
    
    print_message "\n🎉 Installation completed successfully!" "$GREEN"
    print_message "\nTo start the application:" "$YELLOW"
    print_message "1. Start the server: cd server && npm run dev" "$NC"
    print_message "2. Start the client: cd client && npm run dev" "$NC"
}

# Start installation
main
