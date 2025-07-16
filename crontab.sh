#!/bin/bash

# Script to check certificate age, update if needed, and upload to servers
# This script should be run via cron job

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.ini"
UPDATE_SCRIPT="$SCRIPT_DIR/update.sh"
UPLOAD_SCRIPT="$SCRIPT_DIR/upload.sh"

# Get current directory
CURRENT_DIR=$(pwd)
LOG_FILE="$CURRENT_DIR/cert_update.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    log_message "Error: Configuration file $CONFIG_FILE not found"
    exit 1
fi

# Check if scripts exist and are executable
if [ ! -x "$UPDATE_SCRIPT" ]; then
    log_message "Error: Update script $UPDATE_SCRIPT not found or not executable"
    exit 1
fi

if [ ! -x "$UPLOAD_SCRIPT" ]; then
    log_message "Error: Upload script $UPLOAD_SCRIPT not found or not executable"
    exit 1
fi

# Function to parse INI file sections
get_ini_sections() {
    local file=$1
    grep -o '^\[[^]]*\]' "$file" | sed 's/^\[\(.*\)\]$/\1/'
}

# Function to get INI value
get_ini_value() {
    local file=$1
    local section=$2
    local key=$3
    sed -n "/^\[$section\]/,/^\[/p" "$file" | grep "^$key=" | head -1 | cut -d'=' -f2-
}

# Process each domain section in the config file
for cert_domain in $(get_ini_sections "$CONFIG_FILE"); do
    # Get update frequency and servers
    update_frequency=$(get_ini_value "$CONFIG_FILE" "$cert_domain" "update_frequency")
    servers=$(get_ini_value "$CONFIG_FILE" "$cert_domain" "servers")
    
    # Skip if missing required values
    if [ -z "$update_frequency" ] || [ -z "$servers" ]; then
        log_message "Error: Missing configuration for $cert_domain. Skipping."
        continue
    fi
    
    # Certificate file path
    cert_file="$CURRENT_DIR/$cert_domain/fullchain.pem"
    
    # Check if certificate exists
    if [ ! -f "$cert_file" ]; then
        log_message "Certificate for $cert_domain not found. Running initial update..."
        "$UPDATE_SCRIPT" "$cert_domain"
        
        # Check if update was successful
        if [ ! -f "$cert_file" ]; then
            log_message "Failed to create certificate for $cert_domain. Skipping."
            continue
        fi
    fi
    
    # Get certificate modification time in seconds since epoch
    cert_mod_time=$(stat -f "%m" "$cert_file" 2>/dev/null || stat -c "%Y" "$cert_file" 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_message "Error: Could not get modification time of $cert_file"
        continue
    fi
    
    # Get current time in seconds since epoch
    current_time=$(date +%s)
    
    # Calculate age in days
    cert_age_seconds=$((current_time - cert_mod_time))
    cert_age_days=$((cert_age_seconds / 86400))
    
    log_message "Certificate for $cert_domain is $cert_age_days days old (update frequency: $update_frequency days)"
    
    # Check if certificate needs to be updated
    if [ "$cert_age_days" -ge "$update_frequency" ]; then
        log_message "Certificate for $cert_domain is due for renewal"
        
        # Update certificate
        log_message "Updating certificate for $cert_domain..."
        "$UPDATE_SCRIPT" "$cert_domain"
        
        if [ $? -ne 0 ]; then
            log_message "Error: Failed to update certificate for $cert_domain"
            continue
        fi
        
        log_message "Certificate for $cert_domain updated successfully"
        
        # Upload certificate to all servers
        IFS=',' read -ra server_list <<< "$servers"
        for server_info in "${server_list[@]}"; do
            IFS=':' read -r server_domain server_port service_name <<< "$server_info"
            
            log_message "Uploading certificate for $cert_domain to $server_domain..."
            "$UPLOAD_SCRIPT" "$server_domain" "$server_port" "$service_name" "$cert_domain"
            
            if [ $? -ne 0 ]; then
                log_message "Error: Failed to upload certificate for $cert_domain to $server_domain"
                continue
            fi
            
            log_message "Certificate uploaded to $server_domain and $service_name restarted"
        done
    else
        log_message "Certificate for $cert_domain is still valid. No action needed."
    fi
done

log_message "Certificate check and update process completed"
