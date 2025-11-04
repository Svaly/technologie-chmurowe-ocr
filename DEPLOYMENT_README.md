# Azure OCR Application Deployment Guide

This guide explains how to deploy the complete Azure OCR application with automated UI configuration.

## What Gets Deployed

1. **Azure Storage Account** - Stores uploaded images and hosts the static website
2. **Azure Computer Vision** - OCR processing service
3. **OCR Function App** - Processes OCR requests
4. **Storage Function App** - Handles image uploads
5. **Static Website** - The UI hosted on Azure Storage with auto-configured function URLs

## Architecture

```
User Browser → Static Website (UI) → Storage Function → Blob Storage
                                   ↓
                                   → OCR Function → Computer Vision → Extract Text
```

## Deployment Steps

### 1. Prerequisites

- Azure CLI installed and logged in
- Azure subscription
- PowerShell (for the deployment script)

### 2. Deploy Using Bicep

You have three options for deploying the UI:

#### Option A: Deploy with Local index.html (Recommended)

Make sure `index.html` is in the same directory as the bicep file:

```bash
# Login to Azure
az login

# Create a resource group (if needed)
az group create --name ocr-rg --location westeurope

# Deploy the bicep template
az deployment group create \
  --resource-group ocr-rg \
  --template-file chmurowe4.bicep \
  --parameters location=westeurope
```

#### Option B: Deploy with UI from URL

Host your `index.html` on a public URL (GitHub, Blob Storage, etc.) and reference it:

```bash
az deployment group create \
  --resource-group ocr-rg \
  --template-file chmurowe4.bicep \
  --parameters location=westeurope \
  --parameters uiHtmlUrl='https://raw.githubusercontent.com/your-repo/main/index.html'
```

#### Option C: Deploy Infrastructure Only

Deploy without UI, then upload manually later:

```bash
az deployment group create \
  --resource-group ocr-rg \
  --template-file chmurowe4.bicep \
  --parameters location=westeurope
  
# Then upload manually to the $web container in Azure Portal
```

### 3. What Happens During Deployment

The bicep template will:

1. Create all Azure resources (Storage, Functions, Computer Vision, etc.)
2. Deploy the function code to both Function Apps
3. Enable static website hosting on the Storage Account
4. **Automatically generate `config.js`** with the function URLs and access keys
5. Upload `index.html` and `config.js` to the `$web` container
6. Configure CORS to allow the static website to call the functions

### 4. Access Your Application

After deployment completes, you'll see the static website URL in the deployment output:

```
https://<storage-account-name>.z6.web.core.windows.net/
```

The UI will be **automatically configured** with the correct function URLs!

## How the Auto-Configuration Works

### Bicep Template (`chmurowe4.bicep`)

The bicep template:
- Retrieves the function host keys using `listkeys()`
- Constructs the full function URLs with keys
- Passes them as environment variables to the PowerShell deployment script

```bicep
var key = listkeys('${functionApp.id}/host/default', '2022-03-01').masterKey
var key2 = listkeys('${storagefunctionApp.id}/host/default', '2022-03-01').masterKey

var ocrFunctionAppUrl = 'https://${functionApp.properties.defaultHostName}/api/ocr?code=${key}'
var storageFunctionAppUrl = 'https://${storagefunctionApp.properties.defaultHostName}/api/uploadimage?code=${key2}'
```

### PowerShell Script (`enable-static-website-new.ps1`)

The PowerShell script intelligently handles UI deployment:
1. Enables static website hosting on the storage account
2. Generates `config.js` with the function URLs from environment variables
3. Gets `index.html` from:
   - **URL** (if `uiHtmlUrl` parameter provided) - downloads from web
   - **Local file** (if found in current/parent directory) - uses local copy
   - **Fallback** (if neither found) - creates a setup instruction page
4. Uploads both `index.html` and `config.js` to the `$web` container

### UI (`index.html`)

The HTML page:
1. Loads `config.js` on startup
2. If configured, auto-populates the function URLs
3. Shows a "✅ Configured and ready to use!" message
4. Allows manual configuration if needed

## Manual Configuration (For Local Testing)

If you want to test locally or manually configure:

1. Open `index.html` in a browser
2. Click "⚙️ Configuration"
3. Enter your function URLs manually:
   - Storage Function URL: `https://<storage-func>.azurewebsites.net/api/uploadimage?code=<key>`
   - OCR Function URL: `https://<ocr-func>.azurewebsites.net/api/ocr?code=<key>`

## Files Overview

- **`chmurowe4.bicep`** - Main infrastructure template
- **`enable-static-website-new.ps1`** - PowerShell deployment script
- **`index.html`** - UI application
- **`config.js`** - Configuration file (generated during deployment)
- **`ocrFunction/function_app.py`** - OCR function code
- **`storageFunction/function_app.py`** - Storage function code

## Features

✅ Automatic configuration during deployment  
✅ Drag & drop image upload  
✅ Real-time OCR processing  
✅ Beautiful, responsive UI  
✅ CORS pre-configured  
✅ Secure function key management  
✅ Static website hosting  

## Outputs

After deployment, you'll get:
- Static Website URL
- Storage Account Name
- Function App URLs (with keys)
- Computer Vision Endpoint

## Troubleshooting

### Issue: UI shows "Please configure Storage and OCR function URLs"

**Solution**: The `config.js` might not have loaded. Check:
1. Open browser console (F12)
2. Look for `window.CONFIG` object
3. If undefined, manually enter the URLs in the configuration section

### Issue: CORS error when uploading images

**Solution**: The bicep template automatically configures CORS. If you still see errors:
1. Check that the static website URL matches the CORS allowed origin
2. Redeploy the bicep template

### Issue: Functions not responding

**Solution**: 
1. Check function app logs in Azure Portal
2. Verify environment variables are set correctly
3. Ensure Computer Vision service is in the same region

## Clean Up

To remove all resources:

```bash
az group delete --name ocr-rg --yes
```

## Cost Estimation

- **Storage Account**: ~$0.02/month (minimal usage)
- **Function Apps**: Free tier (1M executions/month)
- **Computer Vision**: $1/1000 transactions (S1 tier)

For testing/development, costs should be minimal (<$5/month).

## Security Notes

- Function keys are embedded in the `config.js` (function-level security)
- Blob storage uses SAS tokens with 14-day expiry
- All communication over HTTPS
- Consider using Azure AD authentication for production

## Next Steps

- Add authentication (Azure AD B2C)
- Implement blob lifecycle management
- Add support for multiple languages
- Create CI/CD pipeline
- Add analytics/telemetry

---

**Happy OCR Processing! 🔍📄**

