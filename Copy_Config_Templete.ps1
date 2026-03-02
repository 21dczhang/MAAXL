# JSON Configuration Sync Script
# Syncs configuration files from Template to target folder
# ============================================

$DESKTOP_PATH = "C:\Users\Aurora\Desktop"
$TEMPLATE_FOLDER = Join-Path $DESKTOP_PATH "MaaXL_Template"
$TARGET_FOLDERS = @("MaaXL")

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "JSON Configuration Sync Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to recursively merge JSON objects
# Template values override target values, but target-only keys are preserved
function Merge-JsonObjects {
    param (
        [PSCustomObject]$Template,
        [PSCustomObject]$Target
    )
    
    $result = @{}
    
    # First, copy all properties from target (preserve target-only fields)
    if ($null -ne $Target) {
        $Target.PSObject.Properties | ForEach-Object {
            $result[$_.Name] = $_.Value
        }
    }
    
    # Then, override with template properties
    if ($null -ne $Template) {
        $Template.PSObject.Properties | ForEach-Object {
            $key = $_.Name
            $templateValue = $_.Value
            
            # If both are objects (not arrays), merge recursively
            if ($templateValue -is [PSCustomObject] -and $result.ContainsKey($key) -and $result[$key] -is [PSCustomObject]) {
                $result[$key] = Merge-JsonObjects -Template $templateValue -Target $result[$key]
            }
            else {
                $result[$key] = $templateValue
            }
        }
    }
    
    return [PSCustomObject]$result
}

# Function to process a single JSON file
function Sync-JsonFile {
    param (
        [string]$TemplateFile,
        [string]$TargetFile,
        [string]$FolderName
    )
    
    try {
        # Read template JSON
        $templateContent = Get-Content -Path $TemplateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        
        # Check if target file exists
        if (Test-Path $TargetFile) {
            $targetContent = Get-Content -Path $TargetFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $mergedContent = Merge-JsonObjects -Template $templateContent -Target $targetContent
        }
        else {
            Write-Host "    [NEW] Creating new file" -ForegroundColor Yellow
            $mergedContent = $templateContent
            
            $targetDir = Split-Path -Parent $TargetFile
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
        }
        
        # Write back to target (preserve UTF-8 without BOM)
        $jsonString = $mergedContent | ConvertTo-Json -Depth 100
        [System.IO.File]::WriteAllText($TargetFile, $jsonString, (New-Object System.Text.UTF8Encoding $false))
        
        return $true
    }
    catch {
        Write-Host "    [ERROR] $_" -ForegroundColor Red
        return $false
    }
}

# Validate template folder exists
if (-not (Test-Path $TEMPLATE_FOLDER)) {
    Write-Host "Error: Template folder not found: $TEMPLATE_FOLDER" -ForegroundColor Red
    exit 1
}

# Find all JSON files in template folder
Write-Host "[*] Scanning template folder for JSON files..." -ForegroundColor Yellow
$templateJsonFiles = Get-ChildItem -Path $TEMPLATE_FOLDER -Filter "*.json" -Recurse

if ($templateJsonFiles.Count -eq 0) {
    Write-Host "Warning: No JSON files found in template folder." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($templateJsonFiles.Count) JSON file(s) in template." -ForegroundColor Green
Write-Host ""

# Process each target folder
$totalProcessed = 0
$totalSuccess = 0
$totalFailed = 0

foreach ($targetFolderName in $TARGET_FOLDERS) {
    $targetFolderPath = Join-Path $DESKTOP_PATH $targetFolderName
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Processing: $targetFolderName" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    if (-not (Test-Path $targetFolderPath)) {
        Write-Host "  [SKIP] Folder does not exist: $targetFolderPath" -ForegroundColor Yellow
        Write-Host ""
        continue
    }
    
    foreach ($templateFile in $templateJsonFiles) {
        $relativePath = $templateFile.FullName.Substring($TEMPLATE_FOLDER.Length + 1)
        $targetFile = Join-Path $targetFolderPath $relativePath
        
        Write-Host "  Processing: $relativePath" -ForegroundColor Gray
        
        $totalProcessed++
        if (Sync-JsonFile -TemplateFile $templateFile.FullName -TargetFile $targetFile -FolderName $targetFolderName) {
            $totalSuccess++
            Write-Host "    [OK] Synced successfully" -ForegroundColor Green
        }
        else {
            $totalFailed++
        }
    }
    
    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Sync Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total files processed: $totalProcessed" -ForegroundColor White
Write-Host "Successful: $totalSuccess" -ForegroundColor Green
Write-Host "Failed: $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { "Red" } else { "Green" })
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")