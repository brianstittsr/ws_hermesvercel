# Port allocation utility for multi-customer deployments
# Automatically finds available ports for new customer deployments

param(
    [Parameter(Mandatory=$false)]
    [int]$StartPort = 9120,
    
    [Parameter(Mandatory=$false)]
    [int]$EndPort = 9199,
    
    [Parameter(Mandatory=$false)]
    [int]$Count = 1
)

function Get-AvailablePorts {
    param(
        [int]$StartPort,
        [int]$EndPort,
        [int]$Count
    )
    
    $availablePorts = @()
    $usedPorts = Get-NetTCPConnection -ErrorAction SilentlyContinue | 
                Where-Object { $_.LocalAddress -eq "0.0.0.0" -or $_.LocalAddress -eq "127.0.0.1" } | 
                Select-Object -ExpandProperty LocalPort | 
                Sort-Object -Unique
    
    for ($port = $StartPort; $port -le $EndPort; $port++) {
        if ($port -notin $usedPorts -and $availablePorts.Count -lt $Count) {
            $availablePorts += $port
        }
    }
    
    return $availablePorts
}

function Get-NextAvailablePort {
    param(
        [int]$StartPort,
        [int]$EndPort
    )
    
    $available = Get-AvailablePorts -StartPort $StartPort -EndPort $EndPort -Count 1
    if ($available.Count -gt 0) {
        return $available[0]
    }
    
    return $null
}

function Get-AllCustomerPorts {
    $customerPorts = @{}
    
    # Get all running Hermes containers
    $containers = docker ps --filter "name=hermes" --format "{{.Names}}" 2>$null
    if ($containers) {
        foreach ($container in $containers) {
            # Extract port from container inspection
            $portInfo = docker inspect $container --format "{{.NetworkSettings.Ports}}" 2>$null
            if ($portInfo -match "912(\d+)") {
                $customerName = $container -replace "-dashboard-1", ""
                $customerPorts[$customerName] = $portInfo
            }
        }
    }
    
    return $customerPorts
}

# Main execution
if ($Count -eq 1) {
    $port = Get-NextAvailablePort -StartPort $StartPort -EndPort $EndPort
    if ($port) {
        Write-Output $port
    } else {
        Write-Host "❌ No available ports in range $StartPort-$EndPort" -ForegroundColor Red
        exit 1
    }
} else {
    $ports = Get-AvailablePorts -StartPort $StartPort -EndPort $EndPort -Count $Count
    if ($ports.Count -eq $Count) {
        Write-Output $ports
    } else {
        Write-Host "❌ Only $($ports.Count) available ports found, need $Count" -ForegroundColor Red
        exit 1
    }
}

# Show current customer deployments if requested
if ($args -contains "--show-customers") {
    Write-Host "`n📊 Current Customer Deployments:" -ForegroundColor Cyan
    $customers = Get-AllCustomerPorts
    if ($customers.Count -gt 0) {
        $customers.GetEnumerator() | ForEach-Object {
            Write-Host "  $($_.Key): Port $($_.Value)" -ForegroundColor White
        }
    } else {
        Write-Host "  No active customer deployments found" -ForegroundColor Gray
    }
}
