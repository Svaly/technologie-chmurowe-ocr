# Azure Cloud Shell Deployment Guide

Quick guide to deploy the OCR application using Azure Cloud Shell.

## Prerequisites
- Azure subscription
- Access to Azure Portal

## Deployment Steps

### 1. Open Azure Cloud Shell
1. Go to [Azure Portal](https://portal.azure.com)
2. Click the **Cloud Shell** icon (>_) in the top toolbar
3. Select **PowerShell** when prompted

### 2. Upload Files
Upload these files to Cloud Shell:
- `chmurowe4.bicep`
- `deploy-cloudshell.ps1`

**How to upload:**
- Click the **Upload/Download** button in Cloud Shell toolbar
- Select **Upload** and choose your files

### 3. Run Deployment

**Option A: With defaults (ocr-rg, westeurope)**
```powershell
./deploy-cloudshell.ps1
```

**Option B: Custom resource group and location**
```powershell
./deploy-cloudshell.ps1 -ResourceGroup "my-ocr-rg" -Location "swedencentral"
```

### 4. Review What-If Output
The script will show you what resources will be created:
- Review the changes
- Type `y` to continue or `n` to cancel

### 5. Wait for Deployment
Deployment takes 5-10 minutes. The script will display:
- Your application URL
- Resource names
- Cleanup command

## Example Output
```
🚀 Azure OCR Deployment (Cloud Shell)
======================================

📋 Configuration:
   Resource Group: ocr-rg
   Location: westeurope

🔍 Running What-If analysis...
[Shows resources that will be created]

Continue with actual deployment? (y/n): y

✅ Deployment completed!

🌐 Application URL:
   https://xxxxx.web.core.windows.net

📊 Resources:
   Resource Group: ocr-rg
   OCR Function: ocr-func-xxxxx
   Storage Function: storage-func-xxxxx
```

## Cleanup
To delete all resources:
```powershell
az group delete --name ocr-rg --yes
```

## Troubleshooting

**Resource provider not registered error?**
```
Failed to register resource provider 'microsoft.operationalinsights'
```
The updated script now handles this automatically. If you get this error with an older script, run:
```powershell
az provider register --namespace microsoft.operationalinsights --wait
```

**Permission errors?**
- Ensure you have Contributor role on the subscription

**Deployment fails?**
- Check the error message
- Verify your subscription has required quotas
- Try a different region

**Can't see outputs?**
- Check Azure Portal → Resource Groups → [your-rg]
- Look for Static Website URL in Storage Account

## Tips
- Cloud Shell times out after 20 minutes of inactivity
- Your files persist in Cloud Shell storage
- You can download deployment logs from Cloud Shell

