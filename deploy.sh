#!/usr/bin/env bash

set -euo pipefail
source ./config.env

echo "Creating Resource Group..."
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    > /dev/null
    

echo "Creating Virtual Network..."
az deployment group create \
    --name "NetworkDeployment" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file ./arm/network.json \
    --parameters \
        location="$LOCATION" \
        vnetName="$VNET_NAME" \
        vnetAddressPrefix="$VNET_ADDRESS_PREFIX" \
        subnetName="$SUBNET_NAME" \
        subnetPrefix="$SUBNET_PREFIX" \
        nsgName="$NSG_NAME" \
    > /dev/null

echo "Creating Laod Balancer..."
az deployment group create \
    --name "LoadBalancerDeployment" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file ./arm/load-balancer.json \
    --parameters \
        location="$LOCATION" \
        publicIpName="$PUBLIC_IP_NAME" \
        loadBalancerName="$LB_NAME" \
        frontendName="$FRONTEND_NAME" \
        backendPoolName="$BACKEND_POOL_NAME" \
        probeName="$PROBE_NAME" \
        loadBalancingRuleName="$LB_RULE_NAME" \
    > /dev/null

