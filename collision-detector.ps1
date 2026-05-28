# Collision detection and prevention system for multi-customer deployments
# Ensures instant deployment without resource conflicts

param(
    [Parameter(Mandatory=$false)]
    [string]$CustomerName,
    
    [Parameter(Mandatory=$false)]
    [int]$RequestedPort,
    
    [Parameter(Mandatory=$false)]
    [switch]$QuickCheck,
    
    [Parameter(Mandatory=$false)]
    [switch]$ReserveResources
)

class DeploymentCollision {
    [string]$Type
    [string]$Resource
    [string]$Owner
    [string]$Suggestion
    [bool]$IsBlocking
    
    DeploymentCollision([string]$Type, [string]$Resource, [string]$Owner, [string]$Suggestion, [bool]$IsBlocking) {
        $this.Type = $Type
        $this.Resource = $Resource
        $this.Owner = $Owner
        $this.Suggestion = $Suggestion
        $this.IsBlocking = $IsBlocking
    }
}

function Get-SystemResources {
    return @{
        Ports = Get-NetTCPConnection -ErrorAction SilentlyContinue | 
               Where-Object { $_.LocalAddress -eq "0.0.0.0" -or $_.LocalAddress -eq "127.0.0.1" } | 
               Select-Object -ExpandProperty LocalPort | 
               Sort-Object -Unique
        Volumes = docker volume ls --format "{{.Name}}" 2>$null | Where-Object { $_ -match "hermes-" }
        Networks = docker network ls --format "{{.Name}}" 2>$null | Where-Object { $_ -match "hermes-" }
        Containers = docker ps --format "{{.Names}}" 2>$null | Where-Object { $_ -match "hermes" }
        Projects = docker ps --filter "label=com.docker.compose.project" --format "{{.Label \"com.docker.compose.project\"}}" 2>$null | Sort-Object -Unique
    }
}

function Test-PortCollision {
    param(
        [int]$Port,
        [string]$CustomerName,
        [hashtable]$Resources
    )
    
    $collisions = @()
    
    if ($Port -in $Resources.Ports) {
        $owner = "Unknown"
        $container = $Resources.Containers | Where-Object { 
            $portInfo = docker inspect $_ --format "{{range .NetworkSettings.Ports}}{{.HostPort}}{{end}}" 2>$null
            $portInfo -eq $Port.ToString()
        } | Select-Object -First 1
        
        if ($container) {
            $owner = ($container -replace "-dashboard-1", "" -replace "-gateway-1", "")
        }
        
        $collisions += [DeploymentCollision]::new(
            "Port", 
            $Port, 
            $owner, 
            "Use port-allocator.ps1 to find available port", 
            $true
        )
    }
    
    return $collisions
}

function Test-VolumeCollision {
    param(
        [string]$CustomerName,
        [hashtable]$Resources
    )
    
    $collisions = @()
    $expectedVolume = "hermes-$CustomerName-data"
    
    if ($expectedVolume -in $Resources.Volumes) {
        $collisions += [DeploymentCollision]::new(
            "Volume", 
            $expectedVolume, 
            $CustomerName, 
            "Use different customer name or remove existing volume", 
            $true
        )
    }
    
    return $collisions
}

function Test-NetworkCollision {
    param(
        [string]$CustomerName,
        [hashtable]$Resources
    )
    
    $collisions = @()
    $expectedNetwork = "hermes-$CustomerName-network"
    
    if ($expectedNetwork -in $Resources.Networks) {
        $collisions += [DeploymentCollision]::new(
            "Network", 
            $expectedNetwork, 
            $CustomerName, 
            "Use different customer name or remove existing network", 
            $false
        )
    }
    
    return $collisions
}

function Test-ProjectCollision {
    param(
        [string]$CustomerName,
        [hashtable]$Resources
    )
    
    $collisions = @()
    
    if ($CustomerName -in $Resources.Projects) {
        $collisions += [DeploymentCollision]::new(
            "Project", 
            $CustomerName, 
            $CustomerName, 
            "Stop existing deployment first: customer-manager.ps1 -Action Stop -CustomerName '$CustomerName'", 
            $true
        )
    }
    
    return $collisions
}

function Test-TelegramBotCollision {
    param(
        [string]$CustomerName,
        [hashtable]$Resources
    )
    
    $collisions = @()
    
    # Check if customer has env file with Telegram token
    $envFile = ".env.customer-$CustomerName"
    if (Test-Path $envFile) {
        $envContent = Get-Content $envFile
        $telegramToken = $envContent | Where-Object { $_ -match "TELEGRAM_BOT_TOKEN=" } | Select-Object -First 1
        
        if ($telegramToken) {
            $token = $telegramToken -replace "TELEGRAM_BOT_TOKEN=", ""
            
            # Check if this token is used by other customers
            $otherEnvFiles = Get-ChildItem ".env.customer-*" | Where-Object { $_.Name -ne $envFile }
            foreach ($otherEnv in $otherEnvFiles) {
                $otherContent = Get-Content $otherEnv.FullName
                $otherToken = $otherContent | Where-Object { $_ -match "TELEGRAM_BOT_TOKEN=" } | Select-Object -First 1
                
                if ($otherToken -and ($otherToken -replace "TELEGRAM_BOT_TOKEN=", "") -eq $token) {
                    $otherCustomer = $otherEnv.Name -replace ".env.customer-", ""
                    $collisions += [DeploymentCollision]::new(
                        "TelegramBot", 
                        $token.Substring(0, 10) + "...", 
                        $otherCustomer, 
                        "Generate unique Telegram bot token for each customer", 
                        $true
                    )
                }
            }
        }
    }
    
    return $collisions
}

function Set-DeploymentReservation {
    param(
        [string]$CustomerName,
        [int]$Port
    )
    
    # Create reservation file
    $reservation = @{
        CustomerName = $CustomerName
        Port = $Port
        ReservedAt = Get-Date
        Volume = "hermes-$CustomerName-data"
        Network = "hermes-$CustomerName-network"
    }
    
    $reservationFile = ".reservations\$CustomerName.json"
    if (-not (Test-Path ".reservations")) {
        New-Item -ItemType Directory -Path ".reservations" | Out-Null
    }
    
    $reservation | ConvertTo-Json | Out-File -FilePath $reservationFile
    Write-Host "🔒 Resources reserved for $CustomerName" -ForegroundColor Green
}

function Remove-Reservation {
    param([string]$CustomerName)
    
    $reservationFile = ".reservations\$CustomerName.json"
    if (Test-Path $reservationFile) {
        Remove-Item $reservationFile
        Write-Host "🔓 Reservation removed for $CustomerName" -ForegroundColor Yellow
    }
}

function Test-DeploymentCollisions {
    param(
        [string]$CustomerName,
        [int]$RequestedPort,
        [hashtable]$Resources
    )
    
    $allCollisions = @()
    
    # Test all collision types
    $allCollisions += Test-PortCollision -Port $RequestedPort -CustomerName $CustomerName -Resources $Resources
    $allCollisions += Test-VolumeCollision -CustomerName $CustomerName -Resources $Resources
    $allCollisions += Test-NetworkCollision -CustomerName $CustomerName -Resources $Resources
    $allCollisions += Test-ProjectCollision -CustomerName $CustomerName -Resources $Resources
    $allCollisions += Test-TelegramBotCollision -CustomerName $CustomerName -Resources $Resources
    
    return $allCollisions
}

function Show-CollisionReport {
    param([DeploymentCollision[]]$Collisions)
    
    if ($Collisions.Count -eq 0) {
        Write-Host "✅ No collisions detected" -ForegroundColor Green
        return $true
    }
    
    Write-Host "`n⚠️  COLLISIONS DETECTED:" -ForegroundColor Red
    Write-Host "=" * 50 -ForegroundColor Gray
    
    $blockingCollisions = $Collisions | Where-Object { $_.IsBlocking }
    $nonBlockingCollisions = $Collisions | Where-Object { -not $_.IsBlocking }
    
    if ($blockingCollisions.Count -gt 0) {
        Write-Host "`n🚫 BLOCKING COLLISIONS:" -ForegroundColor Red
        foreach ($collision in $blockingCollisions) {
            Write-Host "   • $($collision.Type): $($collision.Resource) (owned by $($collision.Owner))" -ForegroundColor Red
            Write-Host "     💡 Suggestion: $($collision.Suggestion)" -ForegroundColor Yellow
        }
    }
    
    if ($nonBlockingCollisions.Count -gt 0) {
        Write-Host "`n⚠️  NON-BLOCKING COLLISIONS:" -ForegroundColor Yellow
        foreach ($collision in $nonBlockingCollisions) {
            Write-Host "   • $($collision.Type): $($collision.Resource) (owned by $($collision.Owner))" -ForegroundColor Yellow
            Write-Host "     💡 Suggestion: $($collision.Suggestion)" -ForegroundColor Gray
        }
    }
    
    return $blockingCollisions.Count -eq 0
}

# Main execution
if ($QuickCheck) {
    $resources = Get-SystemResources
    $collisions = Test-DeploymentCollisions -CustomerName $CustomerName -RequestedPort $RequestedPort -Resources $resources
    $canDeploy = Show-CollisionReport -Collisions $collisions
    exit ([int](-not $canDeploy))
}

if ($ReserveResources -and $CustomerName -and $RequestedPort) {
    Set-DeploymentReservation -CustomerName $CustomerName -Port $RequestedPort
    exit 0
}

if ($CustomerName -and $RequestedPort) {
    Write-Host "🔍 Checking deployment collisions for $CustomerName..." -ForegroundColor Cyan
    
    $resources = Get-SystemResources
    $collisions = Test-DeploymentCollisions -CustomerName $CustomerName -RequestedPort $RequestedPort -Resources $resources
    
    $canDeploy = Show-CollisionReport -Collisions $collisions
    
    if ($canDeploy) {
        Write-Host "`n✅ Safe to deploy $CustomerName on port $RequestedPort" -ForegroundColor Green
        
        # Auto-reserve resources
        Set-DeploymentReservation -CustomerName $CustomerName -Port $RequestedPort
    } else {
        Write-Host "`n❌ Cannot deploy $CustomerName - resolve blocking collisions first" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "📊 System Resource Overview:" -ForegroundColor Cyan
    $resources = Get-SystemResources
    
    Write-Host "`n🔌 Used Ports: $($resources.Ports.Count)" -ForegroundColor White
    Write-Host "📦 Hermes Volumes: $($resources.Volumes.Count)" -ForegroundColor White
    Write-Host "🌐 Hermes Networks: $($resources.Networks.Count)" -ForegroundColor White
    Write-Host "🐳 Hermes Containers: $($resources.Containers.Count)" -ForegroundColor White
    Write-Host "📋 Active Projects: $($resources.Projects.Count)" -ForegroundColor White
    
    # Show available ports
    $availablePorts = 9120..9199 | Where-Object { $_ -notin $resources.Ports }
    Write-Host "`n🔢 Available Ports: $($availablePorts.Count) (9120-9199 range)" -ForegroundColor Green
    if ($availablePorts.Count -gt 0) {
        Write-Host "   Next available: $($availablePorts | Select-Object -First 5)" -ForegroundColor Gray
    }
}
