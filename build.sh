#!/usr/bin/env bash

set -euo pipefail

source ./config.env

az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION"

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file ./arm/main.json