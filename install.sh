#!/bin/bash

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to generate a secure random string
generate_secure_key() {
    length=${1:-32}
    tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c ${length}
}

# Configuration variables
PORT=3001
DB_HOST="localhost"
DB_PORT=3306
DB_NAME="tickets"
SMTP_HOST="smtp.office365.com"
SMTP_PORT=587

# Print header
echo "=== Modern Ticketing System Installation ==="

# Gather server configuration
echo -e "\n=== Server Configuration ==="

# Database configuration
read -p "Enter MySQL root username [root]: " DB_ROOT_USER
DB_ROOT_USER=${DB_ROOT_USER:-root}

read -s -p "Enter MySQL root password: " DB_ROOT_PASSWORD
echo

# Generate JWT secret
JWT_SECRET=$(generate_secure_key)

# Email configuration (optional)
echo -e "\n=== Email Configuration (Optional) ==="
read -p "Enter SMTP email (leave empty to skip): " SMTP_USER

if [ ! -z "$SMTP_USER" ]; then
    read -s -p "Enter SMTP password: " SMTP_PASSWORD
    echo
fi

# Azure configuration (optional)
echo -e "\n=== Azure AD Configuration (Optional) ==="
read -p "Enter Azure Client ID (leave empty to skip): " AZURE_CLIENT_ID

if [ ! -z "$AZURE_CLIENT_ID" ]; then
    read -s -p "Enter Azure Client Secret: " AZURE_CLIENT_SECRET
    echo
    read -p "Enter Azure Tenant ID: " AZURE_TENANT_ID
fi

# Setup database
echo -e "\n=== Setting up database ==="

# Generate application database credentials
APP_DB_USER="tickets"
APP_DB_PASSWORD=$(generate_secure_key 16)

# Create database and user
mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_ROOT_USER" -p"$DB_ROOT_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$APP_DB_USER'@'localhost' IDENTIFIED BY '$APP_DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$APP_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database setup completed successfully${NC}"
else
    echo -e "${RED}Error setting up database${NC}"
    exit 1
fi

# Create environment files
echo -e "\n=== Creating environment files ==="

# Server .env
cat > ./server/.env << EOF
# Server Configuration
PORT=$PORT

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
VITE_APP_API_URL=http://localhost:$PORT
VITE_APP_AZURE_CLIENT_ID=$AZURE_CLIENT_ID
VITE_APP_AZURE_TENANT_ID=$AZURE_TENANT_ID
VITE_APP_ENV=development
EOF

echo -e "${GREEN}✓ Environment files created successfully${NC}"

# Install dependencies
echo -e "\n=== Installing dependencies ==="

echo "Installing server dependencies..."
cd server && npm install
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Server dependencies installed successfully${NC}"
else
    echo -e "${RED}Error installing server dependencies${NC}"
    exit 1
fi

cd ..

echo "Installing client dependencies..."
cd client && npm install
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Client dependencies installed successfully${NC}"
else
    echo -e "${RED}Error installing client dependencies${NC}"
    exit 1
fi

cd ..

# Installation complete
echo -e "\n${GREEN}🎉 Installation completed successfully!${NC}"
echo -e "\nTo start the application:"
echo "1. Start the server: cd server && npm run dev"
echo "2. Start the client: cd client && npm run dev"