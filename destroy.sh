#!/usr/bin/env bash

set -euo pipefail
source ./config.env

echo "Deleting all resources associated with Resource Group: $RESOURCE_GROUP."

az group delete \
    --name "$RESOURCE_GROUP" \
    --yes \
    --no-wait

echo "Waiting for Resource Group deletion to complete..."

az group wait \
    --name "$RESOURCE_GROUP" \
    --deleted

echo
echo "Deletion complete."