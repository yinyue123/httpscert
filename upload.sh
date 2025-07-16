#!/bin/bash

# Check if required parameters are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <server_domain> <server_port> <service_name> <cert_domain>"
    echo "Example: $0 example.com 22 nginx example.org"
    exit 1
fi

# Define variables
SERVER_DOMAIN=$1
SERVER_PORT=$2
SERVICE_NAME=$3
CERT_DOMAIN=$4
SSH_KEY="$HOME/.ssh/id_rsa"
SSH_OPTIONS="-i $SSH_KEY -p $SERVER_PORT -o StrictHostKeyChecking=no"
REMOTE_USER="root"

# Get current directory
CURRENT_DIR=$(pwd)

# Check if the SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo "Error: SSH private key not found at $SSH_KEY"
    exit 1
fi

# Define certificate paths
CERT_DIR="$CURRENT_DIR/$CERT_DOMAIN"
CERT_FILE="$CERT_DIR/fullchain.pem"
KEY_FILE="$CERT_DIR/privkey.pem"

# Check if certificates exist
if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "Error: Certificate files not found for $CERT_DOMAIN"
    echo "Expected files: $CERT_FILE and $KEY_FILE"
    exit 1
fi

# Create a directory for the certs on the remote server if it doesn't exist
echo "Creating remote directory if it doesn't exist..."
ssh $SSH_OPTIONS $REMOTE_USER@$SERVER_DOMAIN "mkdir -p /etc/ssl/certs/$CERT_DOMAIN"

# Upload certificates
echo "Uploading certificates for $CERT_DOMAIN to $SERVER_DOMAIN..."
scp $SSH_OPTIONS $CERT_FILE $REMOTE_USER@$SERVER_DOMAIN:/etc/ssl/certs/$CERT_DOMAIN/fullchain.pem
scp $SSH_OPTIONS $KEY_FILE $REMOTE_USER@$SERVER_DOMAIN:/etc/ssl/certs/$CERT_DOMAIN/privkey.pem

# Check if upload was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to upload certificates to $SERVER_DOMAIN"
    exit 1
fi

# Restart service
echo "Restarting $SERVICE_NAME service on $SERVER_DOMAIN..."
ssh $SSH_OPTIONS $REMOTE_USER@$SERVER_DOMAIN "systemctl restart $SERVICE_NAME"

# Check if restart was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to restart $SERVICE_NAME service on $SERVER_DOMAIN"
    exit 1
fi

echo "Success: Certificates for $CERT_DOMAIN uploaded and $SERVICE_NAME service restarted on $SERVER_DOMAIN"
