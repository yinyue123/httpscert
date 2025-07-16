#!/bin/bash

# Check if domain parameter is provided
if [ -z "$1" ]; then
    echo "Usage: $0 domain.com"
    echo "Example: $0 example.com"
    exit 1
fi

# Set domain variables
DOMAIN="$1"
ROOT_DOMAIN="$DOMAIN"
WILDCARD_DOMAIN="*.$DOMAIN"

# Import environment variables from .bashrc
if [ -f .bashrc ]; then
    source .bashrc
    echo "Environment variables loaded from .bashrc"
else
    echo "Warning: .bashrc not found. Make sure all required environment variables are set."
fi

# Get current directory to save certificates
CURRENT_DIR=$(pwd)

# Change to acme.sh directory
if [ -d "./acme.sh" ]; then
    cd ./acme.sh
else
    echo "Error: acme.sh directory not found"
    exit 1
fi

echo "Processing certificates for domain: $DOMAIN"

# Check if certificates already exist
CERT_DIR="$CURRENT_DIR/$DOMAIN"
if [ -d "$CERT_DIR" ]; then
    echo "Certificates directory exists. Attempting to renew certificates..."
    
    # Renew certificates using acme.sh
    # --cert-file: The server certificate file that contains the public key and certificate information.
    #              It's used in SSL/TLS server configurations. Contains only the end-entity certificate.
    #              Used by: Apache, HAProxy (in some configs), and other servers that require separate cert files.
    #
    # --key-file: The private key file used to decrypt data sent by clients.
    #             MUST be kept secure and confidential. All SSL/TLS servers require this file.
    #             Used by: All web servers and services requiring SSL/TLS (Nginx, Apache, HAProxy, etc.)
    #
    # --fullchain-file: The complete certificate chain file that includes both the server certificate
    #                   and all intermediate certificates. Most modern web servers prefer this file
    #                   as it provides the complete chain of trust to clients.
    #                   Used by: Nginx (ssl_certificate directive), Apache 2.4+, most modern web servers
    #                   For Nginx configuration: use this with ssl_certificate directive
    #
    # --ca-file: The Certificate Authority (CA) certificate file containing the certificate of the
    #            authority that issued your certificate. Some services need this to verify the
    #            certificate chain or to establish trust with other services.
    #            Used by: Some Java applications, older servers, client verification systems
    ./acme.sh --renew -d "$ROOT_DOMAIN" -d "$WILDCARD_DOMAIN" --cert-file "$CERT_DIR/cert.pem" --key-file "$CERT_DIR/key.pem" --fullchain-file "$CERT_DIR/fullchain.pem" --ca-file "$CERT_DIR/ca.pem"
    
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        echo "Certificate renewal completed successfully!"
    else
        echo "Certificate renewal failed with exit code $RESULT"
        exit $RESULT
    fi
else
    echo "Certificates directory does not exist. Creating new certificates..."
    
    # Create directory for certificates
    mkdir -p "$CERT_DIR"
    
    # Issue new certificates using acme.sh
    # --cert-file: The server certificate file that contains the public key and certificate information.
    #              It's used in SSL/TLS server configurations. Contains only the end-entity certificate.
    #              Used by: Apache, HAProxy (in some configs), and other servers that require separate cert files.
    #
    # --key-file: The private key file used to decrypt data sent by clients.
    #             MUST be kept secure and confidential. All SSL/TLS servers require this file.
    #             Used by: All web servers and services requiring SSL/TLS (Nginx, Apache, HAProxy, etc.)
    #
    # --fullchain-file: The complete certificate chain file that includes both the server certificate
    #                   and all intermediate certificates. Most modern web servers prefer this file
    #                   as it provides the complete chain of trust to clients.
    #                   Used by: Nginx (ssl_certificate directive), Apache 2.4+, most modern web servers
    #                   For Nginx configuration: use this with ssl_certificate directive
    #
    # --ca-file: The Certificate Authority (CA) certificate file containing the certificate of the
    #            authority that issued your certificate. Some services need this to verify the
    #            certificate chain or to establish trust with other services.
    #            Used by: Some Java applications, older servers, client verification systems
    ./acme.sh --issue -d "$ROOT_DOMAIN" -d "$WILDCARD_DOMAIN" --dns dns_tencent --cert-file "$CERT_DIR/cert.pem" --key-file "$CERT_DIR/key.pem" --fullchain-file "$CERT_DIR/fullchain.pem" --ca-file "$CERT_DIR/ca.pem"
    
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        echo "Certificate creation completed successfully!"
        echo ""
        echo "For Nginx configuration, use these files:"
        echo "ssl_certificate     $CERT_DIR/fullchain.pem;  # Contains server + intermediate certificates"
        echo "ssl_certificate_key $CERT_DIR/key.pem;        # Contains private key"
        echo ""
    else
        echo "Certificate creation failed with exit code $RESULT"
        exit $RESULT
    fi
fi

# Return to original directory
cd "$CURRENT_DIR"
echo "Certificates are available in: $CERT_DIR"
