#!/usr/bin/env bash

set -euo pipefail

# Project Configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/config.env"
SSH_KEY_DIR="$ROOT_DIR/.keys"
SSH_KEY_PATH="$SSH_KEY_DIR/$SSH_KEY_NAME"

# Azure Subscription
echo "Setting Azure subscription..."
az account set \
    --subscription "$AZURE_SUBSCRIPTION_NAME"

# Check Resource Group
echo
echo "Checking Resource Group: $RESOURCE_GROUP"
if [[ "$(az group exists --name "$RESOURCE_GROUP")" == "true" ]]; then
    echo "Deleting all resources associated with Resource Group: $RESOURCE_GROUP"
    az group delete \
        --name "$RESOURCE_GROUP" \
        --yes \
        --no-wait
    echo "Waiting for Resource Group deletion to complete..."
    az group wait \
        --name "$RESOURCE_GROUP" \
        --deleted
    echo "Resource Group deleted."
else
    echo "Resource Group '$RESOURCE_GROUP' does not exist."
fi

# Delete Local SSH Private Key
echo
echo "Checking local SSH private key..."
if [[ -f "$SSH_KEY_PATH" ]]; then
    echo "Deleting local SSH private key:"
    echo "$SSH_KEY_PATH"
    rm -f "$SSH_KEY_PATH"
    echo "Local SSH private key deleted."
else
    echo "Local SSH private key does not exist."
fi

# Remove .keys directory if empty
if [[ -d "$SSH_KEY_DIR" ]]; then
    rmdir "$SSH_KEY_DIR" 2>/dev/null || true
fi

echo
echo "Deletion complete."