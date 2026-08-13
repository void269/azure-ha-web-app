#!/usr/bin/env bash

set -euo pipefail

source ./config.env

echo "Creating Resource Group: $RESOURCE_GROUP..."
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION"

echo "Creating Virtual Network and Subnets..."
az network vnet create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VNET_NAME" \
    --address-prefixes "$VNET_ADDRESS_PREFIX" \
    --subnet-name "$SUBNET_NAME" \
    --subnet-prefixes "$SUBNET_PREFIX"

echo "Creating Network Security Group..."
az network nsg create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NSG_NAME" \
    --location "$LOCATION"

echo "Creating HTTP Inbound Rule..."
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$NSG_NAME" \
    --name "Allow-HTTP" \
    --priority 100 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --destination-port-ranges 80

echo "Creating Public IP for Load Balencer..."
az network public-ip create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PUBLIC_IP_NAME" \
    --sku Standard \
    --allocation-method Static

echo "Creating Network Load Balancer..."
az network lb create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$LB_NAME" \
    --sku Standard \
    --public-ip-address "$PUBLIC_IP_NAME" \
    --frontend-ip-name "$FRONTEND_NAME" \
    --backend-pool-name "$BACKEND_POOL_NAME"

echo "Creating Health Probe for Laod Balancer..."
az network lb probe create \
    --resource-group "$RESOURCE_GROUP" \
    --lb-name "$LB_NAME" \
    --name "$PROBE_NAME" \
    --protocol Tcp \
    --port 80

echo "Creating Laod Balancer Rule..."
az network lb rule create \
    --resource-group "$RESOURCE_GROUP" \
    --lb-name "$LB_NAME" \
    --name "$LB_RULE_NAME" \
    --protocol Tcp \
    --frontend-port 80 \
    --backend-port 80 \
    --frontend-ip-name "$FRONTEND_NAME" \
    --backend-pool-name "$BACKEND_POOL_NAME" \
    --probe-name "$PROBE_NAME"

echo "Creating VM NICs..."
az network nic create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NIC1_NAME" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET_NAME" \
    --network-security-group "$NSG_NAME"

az network nic create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NIC2_NAME" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET_NAME" \
    --network-security-group "$NSG_NAME"