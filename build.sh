#!/usr/bin/env bash

set -euo pipefail

source ./config.env

echo "Creating Resource Group: $RESOURCE_GROUP"
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION"

echo "Deploying Azure Web App: $WEB_APP_NAME"
az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM1_NAME" \
    --nics "$NIC1_NAME" \
    --image "$VM_IMAGE" \
    --size "$VM_SIZE" \
    --admin-username "$ADMIN_USERNAME" \
    --generate-ssh-keys
