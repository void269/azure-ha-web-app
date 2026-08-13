#!/usr/bin/env bash

set -euo pipefail

source ./config.env

echo "Creating Resource Group: $RESOURCE_GROUP"
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION"

