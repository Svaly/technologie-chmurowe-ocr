# Get environment variables passed from Bicep
$storageAccountName = $env:StorageAccountName
$resourceGroupName = $env:ResourceGroupName
$storageFunctionAppUrl = $env:storageFunctionAppUrl
$ocrFunctionAppUrl = $env:ocrFunctionAppUrl
$uiHtmlUrl = $env:uiHtmlUrl

Write-Output "========================================"
Write-Output "Static Website Deployment"
Write-Output "========================================"
Write-Output "Storage Account: $storageAccountName"
Write-Output "Resource Group: $resourceGroupName"
Write-Output ""

# Wait for role assignments to propagate
Write-Output "⏳ Waiting for role assignments to propagate (30 seconds)..."
Start-Sleep -Seconds 30
Write-Output "✅ Ready to proceed"
Write-Output ""

# Get storage account context first
Write-Output "Step 1: Getting storage account context..."
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$ctx = $storageAccount.Context
Write-Output "✅ Storage context retrieved"

# Enable static website hosting
Write-Output ""
Write-Output "Step 2: Enabling static website hosting..."
try {
    Enable-AzStorageStaticWebsite -Context $ctx -IndexDocument index.html -ErrorDocument404Path index.html
    Write-Output "✅ Static website hosting enabled"
} catch {
    Write-Error "Failed to enable static website hosting: $_"
    throw
}

# Create config.js with function URLs
Write-Output ""
Write-Output "Step 3: Creating config.js with function URLs..."
$configContent = @"
// Auto-generated configuration file
// Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") UTC

window.CONFIG = {
    storageUrl: '$storageFunctionAppUrl',
    ocrUrl: '$ocrFunctionAppUrl'
};
"@

# Use /tmp for Linux-based Azure Deployment Scripts or current directory as fallback
$tempDir = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
$tempConfigPath = Join-Path $tempDir "config-$(Get-Date -Format 'yyyyMMddHHmmss').js"
$configContent | Out-File -FilePath $tempConfigPath -Encoding utf8 -NoNewline
Write-Output "✅ config.js created"
Write-Output "   Storage URL: $storageFunctionAppUrl"
Write-Output "   OCR URL: $ocrFunctionAppUrl"

# Get index.html - either download from URL or use local file
Write-Output ""
Write-Output "Step 4: Getting index.html..."
$tempIndexPath = Join-Path $tempDir "index-$(Get-Date -Format 'yyyyMMddHHmmss').html"

if ($uiHtmlUrl -and $uiHtmlUrl -ne '') {
    # Download from URL
    Write-Output "   Downloading from URL: $uiHtmlUrl"
    try {
        Invoke-WebRequest -Uri $uiHtmlUrl -OutFile $tempIndexPath
        Write-Output "✅ index.html downloaded from URL"
    } catch {
        Write-Error "Failed to download index.html from URL: $_"
        throw
    }
} else {
    # Use local file - look in current directory or parent directory
    $localIndexPath = $null
    
    # Try current directory first
    if (Test-Path "index.html") {
        $localIndexPath = "index.html"
    } 
    # Try parent directory (common when running from deployment script context)
    elseif (Test-Path "..\index.html") {
        $localIndexPath = "..\index.html"
    }
    # Try the script root directory
    elseif (Test-Path "$PSScriptRoot\index.html") {
        $localIndexPath = "$PSScriptRoot\index.html"
    }
    
    if ($localIndexPath) {
        Write-Output "   Using local file: $localIndexPath"
        Copy-Item -Path $localIndexPath -Destination $tempIndexPath
        Write-Output "✅ index.html loaded from local file"
    } else {
        # Fallback: create a simple HTML that shows configuration instructions
        Write-Warning "index.html not found. Creating default template..."
        $defaultHtml = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OCR Setup Required</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 600px;
        }
        h1 { color: #333; margin-bottom: 20px; }
        p { color: #666; line-height: 1.6; margin-bottom: 15px; }
        code {
            background: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: monospace;
        }
        .info {
            background: #e3f2fd;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
            border-left: 4px solid #2196F3;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 OCR Application</h1>
        <div class="info">
            <strong>⚠️ Setup Required</strong>
            <p>The UI file (index.html) was not found during deployment.</p>
        </div>
        <p><strong>Your Azure Functions are configured and ready!</strong></p>
        <p>To complete the setup:</p>
        <ol>
            <li>Upload your <code>index.html</code> file to the <code>$web</code> container</li>
            <li>Or provide the <code>uiHtmlUrl</code> parameter during deployment</li>
        </ol>
        <p><strong>Your function endpoints:</strong></p>
        <p style="word-break: break-all; background: #f4f4f4; padding: 10px; border-radius: 5px; font-size: 0.9em;">
            Storage: <script>document.write(window.CONFIG.storageUrl);</script><br>
            OCR: <script>document.write(window.CONFIG.ocrUrl);</script>
        </p>
    </div>
    <script src="config.js"></script>
</body>
</html>
'@
        $defaultHtml | Out-File -FilePath $tempIndexPath -Encoding utf8 -NoNewline
        Write-Output "⚠️  Created default HTML template"
    }
}

# Upload files to $web container
Write-Output ""
Write-Output "Step 5: Uploading files to static website..."

try {
    # Upload config.js
    Write-Output "   Uploading config.js..."
    Set-AzStorageBlobContent -File $tempConfigPath -Container '$web' -Blob "config.js" -Context $ctx -Properties @{"ContentType" = "application/javascript"} -Force | Out-Null
    Write-Output "   ✅ config.js uploaded"
    
    # Upload index.html
    Write-Output "   Uploading index.html..."
    Set-AzStorageBlobContent -File $tempIndexPath -Container '$web' -Blob "index.html" -Context $ctx -Properties @{"ContentType" = "text/html"} -Force | Out-Null
    Write-Output "   ✅ index.html uploaded"
} catch {
    Write-Error "Failed to upload files: $_"
    throw
}

# Get the static website URL
$staticWebsiteUrl = $storageAccount.PrimaryEndpoints.Web

Write-Output ""
Write-Output "========================================"
Write-Output "✅ Deployment Completed Successfully!"
Write-Output "========================================"
Write-Output ""
Write-Output "🌐 Your OCR application is available at:"
Write-Output "   $staticWebsiteUrl"
Write-Output ""
Write-Output "📋 Configuration:"
Write-Output "   • Storage Function: Configured ✓"
Write-Output "   • OCR Function: Configured ✓"
Write-Output "   • Static Website: Enabled ✓"
Write-Output ""

# Clean up temp files
Write-Output "Cleaning up temporary files..."
Remove-Item $tempConfigPath -ErrorAction SilentlyContinue
Remove-Item $tempIndexPath -ErrorAction SilentlyContinue
Write-Output "✅ Cleanup completed"
Write-Output ""
Write-Output "========================================"
