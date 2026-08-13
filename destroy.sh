#!/usr/bin/env bash

set -euo pipefail
source ./config.env

echo "Deleting all resources asssociated with Resource Group: $RESOURCE_GROUP."
az group delete \
    --name "$RESOURCE_GROUP" \
    --yes
    
echo
echo "Deletion complete."