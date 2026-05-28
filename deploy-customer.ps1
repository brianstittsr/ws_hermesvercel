# Multi-customer deployment script for Hermes
# Usage: .\deploy-customer.ps1 -CustomerName "customer-01" -DashboardPort 9120

param(
    [Parameter(Mandatory=$true)]
    [string]$CustomerName,
    
    [Parameter(Mandatory=$true)]
    [int]$DashboardPort,
    
    [Parameter(Mandatory=$false)]
    [string]$TelegramBotToken,
    
    [Parameter(Mandatory=$false)]
    [string]$MattermostToken,
    
    [Parameter(Mandatory=$false)]
    [string]$MattermostUrl,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoStart
)

# Validate port is not already in use
$portInUse = Get-NetTCPConnection -LocalPort $DashboardPort -ErrorAction SilentlyContinue
if ($portInUse) {
    Write-Host "❌ Port $DashboardPort is already in use by process $($portInUse.OwningProcess)" -ForegroundColor Red
    exit 1
}

# Create customer-specific environment file
$envFile = ".env.customer-$CustomerName"
if (-not (Test-Path $envFile)) {
    Write-Host "Creating environment file: $envFile" -ForegroundColor Yellow
    Copy-Item ".env.customer.example" $envFile
    
    # Update the environment file with provided values
    (Get-Content $envFile) | ForEach-Object {
        $_ -replace 'CUSTOMER_NAME=customer-01', "CUSTOMER_NAME=$CustomerName" `
           -replace 'DASHBOARD_PORT=9120', "DASHBOARD_PORT=$DashboardPort" `
           -replace 'your-telegram-bot-token-here', $TelegramBotToken `
           -replace 'your-mattermost-token-here', $MattermostToken `
           -replace 'https://your-mattermost-server.com', $MattermostUrl `
           -replace 'hermes-customer-01-data', "hermes-$CustomerName-data"
    } | Set-Content $envFile
    
    Write-Host "⚠️  Please edit $envFile and set your actual bot tokens and configuration" -ForegroundColor Yellow
    Write-Host "Press Enter to continue after editing..."
    Read-Host
}

# Load environment variables
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
    }
}

# Deploy the customer instance
Write-Host "🚀 Deploying Hermes for customer: $CustomerName" -ForegroundColor Green
Write-Host "📊 Dashboard port: $DashboardPort" -ForegroundColor Cyan
Write-Host "🤖 Telegram bot: Configured" -ForegroundColor Cyan

try {
    # Stop existing instance if running
    docker-compose -f docker-compose.customer.yml -p $CustomerName down
    
    # Start new instance
    docker-compose -f docker-compose.customer.yml -p $CustomerName up -d --build
    
    # Verify deployment
    $timeout = 30
    $running = $false
    for ($i = 0; $i -lt $timeout; $i++) {
        $status = docker-compose -f docker-compose.customer.yml -p $CustomerName ps
        if ($status -match "Up") {
            $running = $true
            break
        }
        Start-Sleep 1
    }
    
    if ($running) {
        Write-Host "✅ Deployment successful!" -ForegroundColor Green
        Write-Host "🌐 Dashboard: http://localhost:$DashboardPort" -ForegroundColor Cyan
        Write-Host "📋 Management commands:" -ForegroundColor White
        Write-Host "   Stop: docker-compose -f docker-compose.customer.yml -p $CustomerName down" -ForegroundColor Gray
        Write-Host "   Logs: docker-compose -f docker-compose.customer.yml -p $CustomerName logs -f" -ForegroundColor Gray
        Write-Host "   Restart: docker-compose -f docker-compose.customer.yml -p $CustomerName restart" -ForegroundColor Gray
        
        # Setup auto-start if requested
        if ($AutoStart) {
            Write-Host "🔧 Setting up auto-start..." -ForegroundColor Yellow
            $startupScript = @"
@echo off
cd /d "$(Get-Location)"
docker-compose -f docker-compose.customer.yml -p $CustomerName up -d
"@
            $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\hermes-$CustomerName.bat"
            $startupScript | Out-File -FilePath $startupPath -Encoding ASCII
            Write-Host "✅ Auto-start configured for $CustomerName" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ Deployment failed - containers not running after $timeout seconds" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "❌ Deployment failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "🎉 Customer deployment complete!" -ForegroundColor Green
