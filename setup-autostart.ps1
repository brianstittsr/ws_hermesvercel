# PowerShell script for Docker and Hermes auto-start setup

Write-Host "Setting up Docker and Hermes auto-start..." -ForegroundColor Green

# Check if Docker Desktop is installed
$dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
if (-not (Test-Path $dockerPath)) {
    Write-Host "Docker Desktop not found at $dockerPath" -ForegroundColor Red
    Write-Host "Please install Docker Desktop first" -ForegroundColor Yellow
    exit 1
}

# Add Docker Desktop to Windows startup
try {
    $startupPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $dockerStartup = Get-ItemProperty -Path $startupPath -Name "Docker Desktop" -ErrorAction SilentlyContinue
    
    if ($dockerStartup) {
        Write-Host "✓ Docker Desktop already configured for auto-start" -ForegroundColor Green
    } else {
        Write-Host "Adding Docker Desktop to Windows startup..." -ForegroundColor Yellow
        Set-ItemProperty -Path $startupPath -Name "Docker Desktop" -Value $dockerPath
        Write-Host "✓ Docker Desktop added to startup" -ForegroundColor Green
    }
} catch {
    Write-Host "Failed to configure Docker auto-start: $_" -ForegroundColor Red
}

# Start Docker Desktop if not running
$dockerProcess = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
if (-not $dockerProcess) {
    Write-Host "Starting Docker Desktop..." -ForegroundColor Yellow
    Start-Process -FilePath $dockerPath
    
    # Wait for Docker to be ready
    Write-Host "Waiting for Docker to start (30 seconds)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
} else {
    Write-Host "✓ Docker Desktop is already running" -ForegroundColor Green
}

# Check if Docker daemon is responsive
try {
    docker version | Out-Null
    Write-Host "✓ Docker daemon is responsive" -ForegroundColor Green
} catch {
    Write-Host "Docker daemon not ready, waiting longer..." -ForegroundColor Yellow
    Start-Sleep -Seconds 20
}

# Start Hermes containers
Write-Host "Starting Hermes containers..." -ForegroundColor Yellow
Set-Location $PSScriptRoot

try {
    docker-compose up -d
    Write-Host "✓ Hermes containers started successfully" -ForegroundColor Green
    Write-Host "Dashboard available at: http://localhost:9119" -ForegroundColor Cyan
} catch {
    Write-Host "Failed to start Hermes containers: $_" -ForegroundColor Red
}

Write-Host "Auto-start setup complete!" -ForegroundColor Green
Write-Host "Hermes will now start automatically when you log into Windows." -ForegroundColor Cyan
