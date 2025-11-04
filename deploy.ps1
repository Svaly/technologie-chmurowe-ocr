# Azure OCR Application Deployment Script (PowerShell)
# This script deploys the complete OCR application to Azure

Write-Host "🚀 Azure OCR Application Deployment" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Check if Azure CLI is installed
try {
    az --version | Out-Null
    Write-Host "✅ Azure CLI is ready" -ForegroundColor Green
} catch {
    Write-Host "❌ Azure CLI is not installed. Please install it first." -ForegroundColor Red
    Write-Host "   Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Check if logged in to Azure
Write-Host "Checking Azure login status..." -ForegroundColor Yellow
try {
    az account show 2>&1 | Out-Null
} catch {
    Write-Host "❌ Not logged in to Azure. Please login first." -ForegroundColor Red
    az login
}

Write-Host ""

# Get parameters
$RESOURCE_GROUP = Read-Host "Enter Resource Group Name (default: ocr-rg)"
if ([string]::IsNullOrWhiteSpace($RESOURCE_GROUP)) {
    $RESOURCE_GROUP = "ocr-rg"
}

$LOCATION = Read-Host "Enter Location (default: westeurope)"
if ([string]::IsNullOrWhiteSpace($LOCATION)) {
    $LOCATION = "westeurope"
}

Write-Host ""
Write-Host "📋 Deployment Configuration:" -ForegroundColor Cyan
Write-Host "   Resource Group: $RESOURCE_GROUP"
Write-Host "   Location: $LOCATION"
Write-Host ""

$CONFIRM = Read-Host "Continue with deployment? (y/n)"
if ($CONFIRM -notmatch '^[yY]') {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Creating resource group if it doesn't exist..." -ForegroundColor Yellow
az group create --name $RESOURCE_GROUP --location $LOCATION --output none
Write-Host "✅ Resource group ready" -ForegroundColor Green

Write-Host ""
Write-Host "🔨 Starting deployment (this may take 5-10 minutes)..." -ForegroundColor Yellow
Write-Host ""

$DEPLOYMENT_NAME = "ocr-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

az deployment group create `
    --resource-group $RESOURCE_GROUP `
    --template-file chmurowe4.bicep `
    --parameters location=$LOCATION `
    --name $DEPLOYMENT_NAME `
    --output json | Out-File -FilePath deployment-output.json

Write-Host ""
Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
Write-Host ""

# Extract outputs from deployment
$STATIC_URL = az deployment group show `
    --resource-group $RESOURCE_GROUP `
    --name $DEPLOYMENT_NAME `
    --query "properties.outputs.staticWebsiteUrl.value" `
    --output tsv 2>$null

$OCR_FUNC = az deployment group show `
    --resource-group $RESOURCE_GROUP `
    --name $DEPLOYMENT_NAME `
    --query "properties.outputs.ocrFunctionAppName.value" `
    --output tsv 2>$null

$STORAGE_FUNC = az deployment group show `
    --resource-group $RESOURCE_GROUP `
    --name $DEPLOYMENT_NAME `
    --query "properties.outputs.storageFunctionAppName.value" `
    --output tsv 2>$null

if ($STATIC_URL) {
    Write-Host "🌐 Your OCR Application is ready at:" -ForegroundColor Green
    Write-Host "   $STATIC_URL" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📊 Deployment Details:" -ForegroundColor Cyan
    Write-Host "   Resource Group: $RESOURCE_GROUP"
    Write-Host "   OCR Function: $OCR_FUNC"
    Write-Host "   Storage Function: $STORAGE_FUNC"
    Write-Host ""
} else {
    Write-Host "⚠️  Could not retrieve deployment outputs. Check Azure Portal." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📊 Deployment Details:" -ForegroundColor Cyan
    Write-Host "   Resource Group: $RESOURCE_GROUP"
    Write-Host "   Deployment Name: $DEPLOYMENT_NAME"
    Write-Host ""
}
Write-Host "💡 Tips:" -ForegroundColor Yellow
Write-Host "   - The application is pre-configured with function URLs"
Write-Host "   - Just upload an image and click 'Process OCR'"
Write-Host "   - Check Azure Portal for detailed resource information"
Write-Host ""
Write-Host "🧹 To delete all resources later, run:" -ForegroundColor Yellow
Write-Host "   az group delete --name $RESOURCE_GROUP --yes" -ForegroundColor White
Write-Host ""

