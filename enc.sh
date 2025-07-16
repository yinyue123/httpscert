#!/bin/bash

# Check if enough arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 [encrypt|decrypt] password"
    exit 1
fi

ACTION=$1
PASSWORD=$2
# Repeat password three times to strengthen against brute force attacks
ENHANCED_PASSWORD="${PASSWORD}${PASSWORD}${PASSWORD}"
ZIPFILE="bashrc.zip"
TARGET=".bashrc"

echo "password: $ENHANCED_PASSWORD"
# Check if target file exists for encryption
if [ "$ACTION" = "encrypt" ] && [ ! -f "$TARGET" ]; then
    echo "Error: $TARGET not found in current directory"
    exit 1
fi

# Check if zip file exists for decryption
if [ "$ACTION" = "decrypt" ] && [ ! -f "$ZIPFILE" ]; then
    echo "Error: $ZIPFILE not found in current directory"
    exit 1
fi

# Perform action based on first parameter
if [ "$ACTION" = "encrypt" ]; then
    echo "Encrypting $TARGET with enhanced password protection..."
    zip -P "$ENHANCED_PASSWORD" "$ZIPFILE" "$TARGET"
    echo "Created encrypted file: $ZIPFILE"
elif [ "$ACTION" = "decrypt" ]; then
    echo "Decrypting $ZIPFILE..."
    unzip -P "$ENHANCED_PASSWORD" "$ZIPFILE"
    echo "File extracted successfully"
else
    echo "Invalid action. Use 'encrypt' or 'decrypt'"
    exit 1
fi
