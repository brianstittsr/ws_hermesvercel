# Customer management utility for multi-tenant Hermes deployments
# Usage examples:
# .\customer-manager.ps1 -Action List
# .\customer-manager.ps1 -Action Deploy -CustomerName "customer-01" -AutoAllocatePort
# .\customer-manager.ps1 -Action Stop -CustomerName "customer-01"
# .\customer-manager.ps1 -Action Remove -CustomerName "customer-01"

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("List", "Deploy", "Stop", "Remove", "Status", "Logs")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$CustomerName,
    
    [Parameter(Mandatory=$false)]
    [int]$DashboardPort,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoAllocatePort,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoStart
)

function Get-CustomerDeployments {
    $deployments = @()
    
    # Get all docker-compose projects with hermes
    $projects = docker ps --filter "label=com.docker.compose.project" --format "table {{.Label \"com.docker.compose.project\"}}\t{{.Names}}\t{{.Status}}" 2>$null
    
    if ($projects) {
        $lines = $projects -split "`n" | Where-Object { $_ -match "hermes" }
        foreach ($line in $lines) {
            if ($line -match "^\s*(\S+)\s+(\S+)\s+(.+)$") {
                $projectName = $matches[1]
                $containerName = $matches[2]
                $status = $matches[3]
                
                if ($projectName -notmatch "^(hermes|hermesvercel)$") { # Exclude default deployment
                    $deployment = @{
                        CustomerName = $projectName
                        ContainerName = $containerName
                        Status = $status
                        Port = $null
                    }
                    
                    # Try to get port information
                    if ($containerName -match "dashboard") {
                        $portInfo = docker inspect $containerName --format "{{range .NetworkSettings.Ports}}{{.HostPort}}{{end}}" 2>$null
                        if ($portInfo) {
                            $deployment.Port = $portInfo
                        }
                    }
                    
                    $deployments += $deployment
                }
            }
        }
    }
    
    return $deployments
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

function Show-CustomerList {
    $deployments = Get-CustomerDeployments
    
    Write-Host "📊 Customer Deployments:" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Gray
    
    if ($deployments.Count -eq 0) {
        Write-Host "No customer deployments found." -ForegroundColor Yellow
        return
    }
    
    $grouped = $deployments | Group-Object CustomerName
    
    foreach ($group in $grouped) {
        Write-Host "`n🏢 Customer: $($group.Name)" -ForegroundColor Green
        foreach ($deployment in $group.Group) {
            $statusIcon = if ($deployment.Status -match "Up") { "✅" } else { "❌" }
            $portInfo = if ($deployment.Port) { " (Port: $($deployment.Port))" } else { "" }
            Write-Host "  $statusIcon $($deployment.ContainerName)$portInfo" -ForegroundColor White
        }
    }
}

function Install-Customer {
    param(
        [string]$CustomerName,
        [int]$DashboardPort,
        [switch]$AutoAllocatePort,
        [switch]$AutoStart
    )
    
    if (-not $CustomerName) {
        Write-Host "❌ Customer name is required for deployment" -ForegroundColor Red
        return
    }
    
    # Check if customer already exists
    $existing = Get-CustomerDeployments | Where-Object { $_.CustomerName -eq $CustomerName }
    if ($existing) {
        Write-Host "❌ Customer '$CustomerName' already exists" -ForegroundColor Red
        Write-Host "Use .\customer-manager.ps1 -Action Stop -CustomerName '$CustomerName' to stop it first" -ForegroundColor Yellow
        return
    }
    
    # Allocate port if needed
    if ($AutoAllocatePort -or -not $DashboardPort) {
        $DashboardPort = Get-NextAvailablePort
        if (-not $DashboardPort) {
            Write-Host "❌ No available ports found" -ForegroundColor Red
            return
        }
        Write-Host "🔢 Allocated port: $DashboardPort" -ForegroundColor Cyan
    }
    
    # Check port availability
    $portInUse = Get-NetTCPConnection -LocalPort $DashboardPort -ErrorAction SilentlyContinue
    if ($portInUse) {
        Write-Host "❌ Port $DashboardPort is already in use" -ForegroundColor Red
        return
    }
    
    # Create environment file if it doesn't exist
    $envFile = ".env.customer-$CustomerName"
    if (-not (Test-Path $envFile)) {
        Write-Host "📝 Creating environment file: $envFile" -ForegroundColor Yellow
        Copy-Item ".env.customer.example" $envFile
        
        # Update the environment file
        (Get-Content $envFile) | ForEach-Object {
            $_ -replace 'CUSTOMER_NAME=customer-01', "CUSTOMER_NAME=$CustomerName" `
               -replace 'DASHBOARD_PORT=9120', "DASHBOARD_PORT=$DashboardPort" `
               -replace 'hermes-customer-01-data', "hermes-$CustomerName-data"
        } | Set-Content $envFile
        
        Write-Host "⚠️  Please edit $envFile and set your actual bot tokens" -ForegroundColor Yellow
        Write-Host "Press Enter to continue..."
        Read-Host
    }
    
    # Deploy
    Write-Host "🚀 Deploying customer: $CustomerName" -ForegroundColor Green
    try {
        docker-compose -f docker-compose.customer.yml -p $CustomerName up -d --build
        
        # Verify deployment
        Start-Sleep 5
        $status = docker-compose -f docker-compose.customer.yml -p $CustomerName ps
        if ($status -match "Up") {
            Write-Host "✅ Deployment successful!" -ForegroundColor Green
            Write-Host "🌐 Dashboard: http://localhost:$DashboardPort" -ForegroundColor Cyan
            
            # Setup auto-start if requested
            if ($AutoStart) {
                $startupScript = @"
@echo off
cd /d "$(Get-Location)"
docker-compose -f docker-compose.customer.yml -p $CustomerName up -d
"@
                $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\hermes-$CustomerName.bat"
                $startupScript | Out-File -FilePath $startupPath -Encoding ASCII
                Write-Host "✅ Auto-start configured" -ForegroundColor Green
            }
        } else {
            Write-Host "❌ Deployment failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Deployment error: $_" -ForegroundColor Red
    }
}

function Stop-Customer {
    param([string]$CustomerName)
    
    if (-not $CustomerName) {
        Write-Host "❌ Customer name is required" -ForegroundColor Red
        return
    }
    
    Write-Host "🛑 Stopping customer: $CustomerName" -ForegroundColor Yellow
    try {
        docker-compose -f docker-compose.customer.yml -p $CustomerName down
        Write-Host "✅ Customer stopped" -ForegroundColor Green
    } catch {
        Write-Host "❌ Stop error: $_" -ForegroundColor Red
    }
}

function Remove-Customer {
    param([string]$CustomerName)
    
    if (-not $CustomerName) {
        Write-Host "❌ Customer name is required" -ForegroundColor Red
        return
    }
    
    Write-Host "🗑️  Removing customer: $CustomerName" -ForegroundColor Red
    try {
        docker-compose -f docker-compose.customer.yml -p $CustomerName down -v
        
        # Remove startup script if exists
        $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\hermes-$CustomerName.bat"
        if (Test-Path $startupPath) {
            Remove-Item $startupPath
            Write-Host "✅ Auto-start removed" -ForegroundColor Green
        }
        
        # Remove environment file
        $envFile = ".env.customer-$CustomerName"
        if (Test-Path $envFile) {
            Remove-Item $envFile
            Write-Host "✅ Environment file removed" -ForegroundColor Green
        }
        
        Write-Host "✅ Customer completely removed" -ForegroundColor Green
    } catch {
        Write-Host "❌ Remove error: $_" -ForegroundColor Red
    }
}

function Show-CustomerStatus {
    param([string]$CustomerName)
    
    if ($CustomerName) {
        # Show specific customer status
        Write-Host "📊 Status for: $CustomerName" -ForegroundColor Cyan
        try {
            docker-compose -f docker-compose.customer.yml -p $CustomerName ps
        } catch {
            Write-Host "❌ Customer '$CustomerName' not found" -ForegroundColor Red
        }
    } else {
        # Show all customers
        Show-CustomerList
    }
}

function Show-CustomerLogs {
    param([string]$CustomerName)
    
    if (-not $CustomerName) {
        Write-Host "❌ Customer name is required" -ForegroundColor Red
        return
    }
    
    Write-Host "📋 Logs for: $CustomerName" -ForegroundColor Cyan
    try {
        docker-compose -f docker-compose.customer.yml -p $CustomerName logs -f
    } catch {
        Write-Host "❌ Cannot access logs for '$CustomerName'" -ForegroundColor Red
    }
}

# Main execution
switch ($Action) {
    "List" { Show-CustomerList }
    "Deploy" { Install-Customer -CustomerName $CustomerName -DashboardPort $DashboardPort -AutoAllocatePort:$AutoAllocatePort -AutoStart:$AutoStart }
    "Stop" { Stop-Customer -CustomerName $CustomerName }
    "Remove" { Remove-Customer -CustomerName $CustomerName }
    "Status" { Show-CustomerStatus -CustomerName $CustomerName }
    "Logs" { Show-CustomerLogs -CustomerName $CustomerName }
    default { Write-Host "❌ Unknown action: $Action" -ForegroundColor Red }
}
