# Azure Cloud Shell - OCR Application Deployment
# Simple deployment script with what-if validation

param(
    [string]$ResourceGroup = "ocr-rg",
    [string]$Location = "westeurope"
)

Write-Host "🚀 Azure OCR Deployment (Cloud Shell)" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Configuration:" -ForegroundColor Yellow
Write-Host "   Resource Group: $ResourceGroup"
Write-Host "   Location: $Location"
Write-Host ""

# Register required resource providers
Write-Host "🔧 Registering required Azure providers..." -ForegroundColor Yellow
az provider register --namespace microsoft.operationalinsights --wait
az provider register --namespace Microsoft.Web --wait
az provider register --namespace Microsoft.Storage --wait
az provider register --namespace Microsoft.CognitiveServices --wait
Write-Host "✅ Providers registered" -ForegroundColor Green
Write-Host ""

# Create resource group
Write-Host "📦 Creating resource group..." -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Location --output none
Write-Host "✅ Resource group ready" -ForegroundColor Green
Write-Host ""

# What-If Deployment
Write-Host "🔍 Running What-If analysis..." -ForegroundColor Yellow
Write-Host ""
az deployment group what-if `
    --resource-group $ResourceGroup `
    --template-file chmurowe4.bicep `
    --parameters location=$Location

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
$CONFIRM = Read-Host "Continue with actual deployment? (y/n)"
if ($CONFIRM -notmatch '^[yY]') {
    Write-Host "❌ Deployment cancelled" -ForegroundColor Yellow
    exit 0
}

# Actual Deployment
Write-Host ""
Write-Host "🔨 Starting deployment..." -ForegroundColor Yellow
$DEPLOYMENT_NAME = "ocr-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

az deployment group create `
    --resource-group $ResourceGroup `
    --template-file chmurowe4.bicep `
    --parameters location=$Location `
    --name $DEPLOYMENT_NAME

Write-Host ""
Write-Host "✅ Deployment completed!" -ForegroundColor Green
Write-Host ""

# Get deployment status and outputs
Write-Host "📊 Retrieving deployment information..." -ForegroundColor Yellow

$deploymentInfo = az deployment group show `
    --resource-group $ResourceGroup `
    --name $DEPLOYMENT_NAME `
    --output json 2>$null | ConvertFrom-Json

if ($deploymentInfo) {
    $provisioningState = $deploymentInfo.properties.provisioningState
    Write-Host "   Deployment State: $provisioningState" -ForegroundColor $(if ($provisioningState -eq 'Succeeded') { 'Green' } else { 'Yellow' })
    
    # Get outputs
    $outputs = $deploymentInfo.properties.outputs
    
    if ($outputs) {
        $STATIC_URL = $outputs.staticWebsiteUrl.value
        $OCR_FUNC = $outputs.ocrFunctionAppName.value
        $STORAGE_FUNC = $outputs.storageFunctionAppName.value
        $OCR_URL = $outputs.ocrFunctionUrl.value
        $STORAGE_URL = $outputs.storageFunctionUrl.value
        
        Write-Host ""
        Write-Host "🌐 Application URL:" -ForegroundColor Green
        Write-Host "   $STATIC_URL" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "📊 Resources:" -ForegroundColor Cyan
        Write-Host "   Resource Group: $ResourceGroup"
        Write-Host "   OCR Function: $OCR_FUNC"
        Write-Host "   Storage Function: $STORAGE_FUNC"
        Write-Host ""
        Write-Host "🔗 Function Endpoints:" -ForegroundColor Cyan
        Write-Host "   OCR API: $OCR_URL" -ForegroundColor White
        Write-Host "   Storage API: $STORAGE_URL" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "⚠️  No outputs found. Checking resources manually..." -ForegroundColor Yellow
        
        # Fallback: get resources from resource group
        $resources = az resource list --resource-group $ResourceGroup --output json | ConvertFrom-Json
        $storageAccount = $resources | Where-Object { $_.type -eq 'Microsoft.Storage/storageAccounts' } | Select-Object -First 1
        
        if ($storageAccount) {
            $storageDetails = az storage account show --name $storageAccount.name --resource-group $ResourceGroup --output json | ConvertFrom-Json
            $STATIC_URL = $storageDetails.primaryEndpoints.web
            
            Write-Host ""
            Write-Host "🌐 Application URL:" -ForegroundColor Green
            Write-Host "   $STATIC_URL" -ForegroundColor Cyan
            Write-Host ""
        }
    }
    
    # Check if deployment script failed but main resources succeeded
    if ($provisioningState -ne 'Succeeded') {
        Write-Host "⚠️  Note: Deployment script may have failed, but main resources are deployed." -ForegroundColor Yellow
        Write-Host "   You may need to run the static website setup manually." -ForegroundColor Yellow
        Write-Host ""
    }
} else {
    Write-Host "❌ Could not retrieve deployment information" -ForegroundColor Red
}

Write-Host "🧹 Cleanup command:" -ForegroundColor Yellow
Write-Host "   az group delete --name $ResourceGroup --yes" -ForegroundColor White
Write-Host ""

