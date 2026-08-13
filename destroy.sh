#!/usr/bin/env bash

set -euo pipefail

source ./config.env

echo "Deleting Resource Group: $RESOURCE_GROUP"
az group delete \
    --name "$RESOURCE_GROUP" \
    --yes \
    --no-wait \
    > /dev/null