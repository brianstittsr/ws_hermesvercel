# Rapid deployment system for instant multi-customer setup
# Pre-validates all resources and deploys in seconds

param(
    [Parameter(Mandatory=$true)]
    [string]$CustomerName,
    
    [Parameter(Mandatory=$false)]
    [int]$SpecificPort,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoPort,
    
    [Parameter(Mandatory=$false)]
    [switch]$BusinessSkills,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipValidation,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

class RapidDeploymentResult {
    [bool]$Success
    [string]$CustomerName
    [int]$Port
    [string]$DashboardUrl
    [string]$Message
    [datetime]$DeployedAt
    [timespan]$DeploymentTime
    
    RapidDeploymentResult([bool]$Success, [string]$CustomerName, [int]$Port, [string]$Message, [timespan]$DeploymentTime) {
        $this.Success = $Success
        $this.CustomerName = $CustomerName
        $this.Port = $Port
        $this.Message = $Message
        $this.DeployedAt = Get-Date
        $this.DeploymentTime = $DeploymentTime
        $this.DashboardUrl = "http://localhost:$Port"
    }
}

function Get-NextAvailablePort {
    $startPort = 9120
    $endPort = 9199
    
    $usedPorts = Get-NetTCPConnection -ErrorAction SilentlyContinue | 
                Where-Object { $_.LocalAddress -eq "0.0.0.0" -or $_.LocalAddress -eq "127.0.0.1" } | 
                Select-Object -ExpandProperty LocalPort | 
                Sort-Object -Unique
    
    for ($port = $startPort; $port -le $endPort; $port++) {
        if ($port -notin $usedPorts) {
            return $port
        }
    }
    
    return $null
}

function New-CustomerEnvironment {
    param(
        [string]$CustomerName,
        [int]$Port,
        [switch]$BusinessSkills
    )
    
    $envFile = ".env.customer-$CustomerName"
    
    if (-not (Test-Path $envFile) -or $Force) {
        Write-Host "📝 Creating customer environment: $CustomerName" -ForegroundColor Yellow
        
        # Copy template
        Copy-Item ".env.customer.example" $envFile -Force
        
        # Update with customer-specific values
        $envContent = Get-Content $envFile
        $envContent = $envContent | ForEach-Object {
            $_ -replace 'CUSTOMER_NAME=customer-01', "CUSTOMER_NAME=$CustomerName" `
               -replace 'DASHBOARD_PORT=9120', "DASHBOARD_PORT=$Port" `
               -replace 'hermes-customer-01-data', "hermes-$CustomerName-data"
        }
        
        # Add business skills configuration if requested
        if ($BusinessSkills) {
            $businessConfig = @"

# Business Skills Configuration
BUSINESS_SKILLS_ENABLED=true
BUSINESS_WEBSITE_MANAGEMENT=true
BUSINESS_AUTOMATION=true
BUSINESS_ANALYTICS=true
BUSINESS_CUSTOMER_SERVICE=true
"@
            $envContent += $businessConfig
        }
        
        $envContent | Set-Content $envFile
        
        Write-Host "✅ Environment file created: $envFile" -ForegroundColor Green
        Write-Host "⚠️  Edit this file to add your Telegram bot token and other settings" -ForegroundColor Yellow
    }
}

function Test-Readiness {
    param([string]$CustomerName, [int]$Port)
    
    $timeout = 30
    $interval = 2
    $elapsed = 0
    
    Write-Host "⏳ Testing deployment readiness..." -ForegroundColor Cyan
    
    while ($elapsed -lt $timeout) {
        try {
            # Test dashboard accessibility
            $response = Invoke-WebRequest -Uri "http://localhost:$Port" -TimeoutSec 5 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Host "✅ Dashboard is ready!" -ForegroundColor Green
                return $true
            }
        } catch {
            # Still starting up
        }
        
        Start-Sleep $interval
        $elapsed += $interval
        Write-Host "." -NoNewline -ForegroundColor Gray
    }
    
    Write-Host "`n❌ Dashboard not ready after $timeout seconds" -ForegroundColor Red
    return $false
}

function Add-BusinessSkills {
    param([string]$CustomerName)
    
    Write-Host "🏢 Adding business skills templates..." -ForegroundColor Cyan
    
    # Create business skills directory
    $skillsDir = ".reservations\skills-$CustomerName"
    if (-not (Test-Path $skillsDir)) {
        New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
    }
    
    # Business skills templates
    $websiteManagement = @"
# Website Management Skill for $CustomerName
# Automated website updates, monitoring, and optimization

name: website-management
description: "Automated website management and optimization"
version: "1.0.0"

triggers:
  - type: schedule
    schedule: "0 */6 * * *"  # Every 6 hours
    
actions:
  - check-website-health
  - update-content
  - optimize-performance
  - backup-website
"@
    
    $customerService = @"
# Customer Service Automation for $CustomerName
# Automated customer support and response management

name: customer-service
description: "Automated customer service and support"
version: "1.0.0"

triggers:
  - type: webhook
    endpoint: "/customer-service"
    
actions:
  - analyze-inquiry
  - generate-response
  - escalate-if-needed
  - log-interaction
"@
    
    $analytics = @"
# Business Analytics for $CustomerName
# Automated business intelligence and reporting

name: business-analytics
description: "Business analytics and reporting automation"
version: "1.0.0"

triggers:
  - type: schedule
    schedule: "0 0 * * *"  # Daily
    
actions:
  - collect-metrics
  - generate-reports
  - send-dashboard
  - archive-data
"@
    
    # Save skill templates
    $websiteManagement | Out-File -FilePath "$skillsDir\website-management.md" -Encoding UTF8
    $customerService | Out-File -FilePath "$skillsDir\customer-service.md" -Encoding UTF8
    $analytics | Out-File -FilePath "$skillsDir\business-analytics.md" -Encoding UTF8
    
    Write-Host "✅ Business skills templates added for $CustomerName" -ForegroundColor Green
}

function Invoke-RapidDeployment {
    param(
        [string]$CustomerName,
        [int]$Port,
        [switch]$BusinessSkills,
        [switch]$SkipValidation
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        Write-Host "🚀 Starting rapid deployment for $CustomerName..." -ForegroundColor Green
        
        # Step 1: Collision detection (unless skipped)
        if (-not $SkipValidation) {
            Write-Host "🔍 Checking for collisions..." -ForegroundColor Cyan
            $collisionCheck = & ".\collision-detector.ps1" -CustomerName $CustomerName -RequestedPort $Port -QuickCheck
            if ($collisionCheck -ne 0) {
                throw "Deployment blocked by resource collisions"
            }
        }
        
        # Step 2: Create environment
        New-CustomerEnvironment -CustomerName $CustomerName -Port $Port -BusinessSkills:$BusinessSkills
        
        # Step 3: Stop existing deployment if any
        Write-Host "🛑 Cleaning up any existing deployment..." -ForegroundColor Yellow
        docker-compose -f docker-compose.customer.yml -p $CustomerName down 2>$null | Out-Null
        
        # Step 4: Deploy containers
        Write-Host "🐳 Deploying containers..." -ForegroundColor Cyan
        $deployResult = docker-compose -f docker-compose.customer.yml -p $CustomerName up -d --build 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Container deployment failed: $deployResult"
        }
        
        # Step 5: Add business skills if requested
        if ($BusinessSkills) {
            Add-BusinessSkills -CustomerName $CustomerName
        }
        
        # Step 6: Test readiness
        if (-not (Test-Readiness -CustomerName $CustomerName -Port $Port)) {
            throw "Deployment failed readiness check"
        }
        
        $stopwatch.Stop()
        
        return [RapidDeploymentResult]::new(
            $true,
            $CustomerName,
            $Port,
            "Deployment completed successfully",
            $stopwatch.Elapsed
        )
        
    } catch {
        $stopwatch.Stop()
        return [RapidDeploymentResult]::new(
            $false,
            $CustomerName,
            $Port,
            "Deployment failed: $($_.Exception.Message)",
            $stopwatch.Elapsed
        )
    }
}

# Main execution
$startTime = Get-Date

Write-Host "⚡ RAPID DEPLOYMENT SYSTEM" -ForegroundColor Magenta
Write-Host "=" * 40 -ForegroundColor Gray

# Determine port
$targetPort = $SpecificPort
if ($AutoPort -or -not $targetPort) {
    $targetPort = Get-NextAvailablePort
    if (-not $targetPort) {
        Write-Host "❌ No available ports found" -ForegroundColor Red
        exit 1
    }
    Write-Host "🔢 Auto-allocated port: $targetPort" -ForegroundColor Cyan
}

# Validate customer name
if ($CustomerName -match '[^a-zA-Z0-9\-_]') {
    Write-Host "❌ Customer name contains invalid characters. Use letters, numbers, hyphens, and underscores only." -ForegroundColor Red
    exit 1
}

# Execute rapid deployment
$result = Invoke-RapidDeployment -CustomerName $CustomerName -Port $targetPort -BusinessSkills:$BusinessSkills -SkipValidation:$SkipValidation

# Display results
Write-Host "`n" + "=" * 40 -ForegroundColor Gray
if ($result.Success) {
    Write-Host "✅ RAPID DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
    Write-Host "🏢 Customer: $($result.CustomerName)" -ForegroundColor White
    Write-Host "🌐 Dashboard: $($result.DashboardUrl)" -ForegroundColor Cyan
    Write-Host "⏱️  Deployment Time: $($result.DeploymentTime.TotalSeconds.ToString('F2'))s" -ForegroundColor Yellow
    
    if ($BusinessSkills) {
        Write-Host "🏢 Business Skills: Enabled" -ForegroundColor Green
    }
    
    Write-Host "`n📋 Management Commands:" -ForegroundColor White
    Write-Host "   Stop: .\customer-manager.ps1 -Action Stop -CustomerName '$($result.CustomerName)'" -ForegroundColor Gray
    Write-Host "   Logs: .\customer-manager.ps1 -Action Logs -CustomerName '$($result.CustomerName)'" -ForegroundColor Gray
    Write-Host "   Status: .\customer-manager.ps1 -Action Status -CustomerName '$($result.CustomerName)'" -ForegroundColor Gray
    
} else {
    Write-Host "❌ RAPID DEPLOYMENT FAILED!" -ForegroundColor Red
    Write-Host "🏢 Customer: $($result.CustomerName)" -ForegroundColor White
    Write-Host "⏱️  Time Elapsed: $($result.DeploymentTime.TotalSeconds.ToString('F2'))s" -ForegroundColor Yellow
    Write-Host "📝 Error: $($result.Message)" -ForegroundColor Red
    
    Write-Host "`n🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1. Check port availability: .\port-allocator.ps1" -ForegroundColor Gray
    Write-Host "   2. Run collision check: .\collision-detector.ps1 -CustomerName '$CustomerName' -RequestedPort $targetPort" -ForegroundColor Gray
    Write-Host "   3. Force deployment: .\rapid-deploy.ps1 -CustomerName '$CustomerName' -Port $targetPort -Force" -ForegroundColor Gray
}

$totalTime = (Get-Date) - $startTime
Write-Host "`n⏱️  Total Process Time: $($totalTime.TotalSeconds.ToString('F2'))s" -ForegroundColor Magenta

exit ([int](-not $result.Success))
