#!/usr/bin/env bash

set -euo pipefail

# Project Configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/config.env"

SSH_KEY_DIR="$ROOT_DIR/.keys"
SSH_KEY_PATH="$SSH_KEY_DIR/$SSH_KEY_NAME"

# Prerequisites
if ! command -v az &>/dev/null; then
    echo "ERROR: Azure CLI is required but is not installed."
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but is not installed."
    exit 1
fi

# Azure Subscription
echo "Setting Azure subscription..."
az account set \
    --subscription "$AZURE_SUBSCRIPTION_NAME"

# Retrieve Subscription ID
AZURE_SUBSCRIPTION_ID="$(
    az account show \
        --query id \
        --output tsv
)"
echo "Subscription: $AZURE_SUBSCRIPTION_NAME"
echo "Subscription ID: $AZURE_SUBSCRIPTION_ID"

# Check if Resource Group already exists
echo
echo "Checking for existing Resource Group: $RESOURCE_GROUP"

if [[ "$(az group exists --name "$RESOURCE_GROUP")" == "true" ]]; then
    echo
    echo "ERROR: Resource Group '$RESOURCE_GROUP' already exists."
    echo
    echo "Run ./destroy.sh before creating a new deployment."
    exit 1
fi

# Resource Group
echo
echo "Creating Resource Group: $RESOURCE_GROUP"

az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output none

# SSH Key
echo
echo "Generating new SSH key pair..."

mkdir -p "$SSH_KEY_DIR"

# Remove any leftover local private key
if [[ -f "$SSH_KEY_PATH" ]]; then
    echo "Removing existing local SSH private key..."
    rm -f "$SSH_KEY_PATH"
fi

# Create Azure SSH public-key resource
echo "Creating Azure SSH public key resource..."

az rest \
    --method put \
    --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/sshPublicKeys/$SSH_KEY_NAME?api-version=2025-04-01" \
    --body "{\"location\":\"$LOCATION\"}" \
    --output none

# Generate SSH key pair in Azure
echo "Generating SSH key pair in Azure..."

KEY_RESPONSE="$(
    az rest \
        --method post \
        --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/sshPublicKeys/$SSH_KEY_NAME/generateKeyPair?api-version=2025-11-01"
)"

# Save Private Key locally
echo "$KEY_RESPONSE" \
    | jq -r '.privateKey' \
    > "$SSH_KEY_PATH"

chmod 600 "$SSH_KEY_PATH"

echo
echo "SSH private key saved:"
echo "$SSH_KEY_PATH"

# Retrieve Public Key from Azure
SSH_PUBLIC_KEY="$(
    az sshkey show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$SSH_KEY_NAME" \
        --query publicKey \
        --output tsv
)"

# Deploying the Network
echo
echo "Deploying networking resources..."

az deployment group create \
    --name "NetworkDeployment" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$ROOT_DIR/arm/network.json" \
    --parameters \
        location="$LOCATION" \
        vnetName="$VNET_NAME" \
        vnetAddressPrefix="$VNET_ADDRESS_PREFIX" \
        subnetName="$SUBNET_NAME" \
        subnetPrefix="$SUBNET_PREFIX" \
        nsgName="$NSG_NAME" \
    --output none

echo "Networking deployment complete."

# Deploying the Load Balancer
echo
echo "Deploying Load Balancer..."

az deployment group create \
    --name "LoadBalancerDeployment" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$ROOT_DIR/arm/load-balancer.json" \
    --parameters \
        location="$LOCATION" \
        publicIpName="$PUBLIC_IP_NAME" \
        loadBalancerName="$LB_NAME" \
        frontendName="$FRONTEND_NAME" \
        backendPoolName="$BACKEND_POOL_NAME" \
        probeName="$PROBE_NAME" \
        loadBalancingRuleName="$LB_RULE_NAME" \
    --output none

echo "Load Balancer deployment complete."

# Deploying Virtual Machines
echo
echo "Deploying Virtual Machines..."

az deployment group create \
    --name "VMDeployment" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$ROOT_DIR/arm/vm.json" \
    --parameters \
        location="$LOCATION" \
        vnetName="$VNET_NAME" \
        subnetName="$SUBNET_NAME" \
        loadBalancerName="$LB_NAME" \
        backendPoolName="$BACKEND_POOL_NAME" \
        nic1Name="$NIC1_NAME" \
        nic2Name="$NIC2_NAME" \
        vm1Name="$VM1_NAME" \
        vm2Name="$VM2_NAME" \
        vmSize="$VM_SIZE" \
        adminUsername="$ADMIN_USERNAME" \
        sshPublicKey="$SSH_PUBLIC_KEY" \
    --output none

echo "Virtual Machine deployment complete."

# Deployment Output
PUBLIC_IP="$(
    az network public-ip show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$PUBLIC_IP_NAME" \
        --query ipAddress \
        --output tsv
)"

echo
echo "Deployment complete."
echo
echo "Load Balancer Public IP: $PUBLIC_IP"
echo "Web URL: http://$PUBLIC_IP"
echo
echo "SSH private key:"
echo "$SSH_KEY_PATH"