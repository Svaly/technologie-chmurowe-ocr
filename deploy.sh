#!/bin/bash

# Azure OCR Application Deployment Script
# This script deploys the complete OCR application to Azure

set -e

echo "🚀 Azure OCR Application Deployment"
echo "===================================="
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first."
    echo "   Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
echo "Checking Azure login status..."
az account show &> /dev/null || {
    echo "❌ Not logged in to Azure. Please login first."
    az login
}

echo "✅ Azure CLI is ready"
echo ""

# Get parameters
read -p "Enter Resource Group Name (default: ocr-rg): " RESOURCE_GROUP
RESOURCE_GROUP=${RESOURCE_GROUP:-ocr-rg}

read -p "Enter Location (default: westeurope): " LOCATION
LOCATION=${LOCATION:-westeurope}

echo ""
echo "📋 Deployment Configuration:"
echo "   Resource Group: $RESOURCE_GROUP"
echo "   Location: $LOCATION"
echo ""

read -p "Continue with deployment? (y/n): " CONFIRM
if [[ $CONFIRM != [yY] && $CONFIRM != [yY][eE][sS] ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Creating resource group if it doesn't exist..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
echo "✅ Resource group ready"

echo ""
echo "🔨 Starting deployment (this may take 5-10 minutes)..."
echo ""

DEPLOYMENT_NAME="ocr-deployment-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file chmurowe4.bicep \
    --parameters location="$LOCATION" \
    --name "$DEPLOYMENT_NAME" \
    --output json > deployment-output.json

echo ""
echo "✅ Deployment completed successfully!"
echo ""

# Extract outputs from deployment
STATIC_URL=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query "properties.outputs.staticWebsiteUrl.value" \
    --output tsv 2>/dev/null || echo "")

OCR_FUNC=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query "properties.outputs.ocrFunctionAppName.value" \
    --output tsv 2>/dev/null || echo "")

STORAGE_FUNC=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query "properties.outputs.storageFunctionAppName.value" \
    --output tsv 2>/dev/null || echo "")

if [ -n "$STATIC_URL" ]; then
    echo "🌐 Your OCR Application is ready at:"
    echo "   $STATIC_URL"
    echo ""
    echo "📊 Deployment Details:"
    echo "   Resource Group: $RESOURCE_GROUP"
    echo "   OCR Function: $OCR_FUNC"
    echo "   Storage Function: $STORAGE_FUNC"
    echo ""
else
    echo "⚠️  Could not retrieve deployment outputs. Check Azure Portal."
    echo ""
    echo "📊 Deployment Details:"
    echo "   Resource Group: $RESOURCE_GROUP"
    echo "   Deployment Name: $DEPLOYMENT_NAME"
    echo ""
fi
echo "💡 Tips:"
echo "   - The application is pre-configured with function URLs"
echo "   - Just upload an image and click 'Process OCR'"
echo "   - Check Azure Portal for detailed resource information"
echo ""
echo "🧹 To delete all resources later, run:"
echo "   az group delete --name $RESOURCE_GROUP --yes"
echo ""

